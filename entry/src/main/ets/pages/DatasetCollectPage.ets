import { router, window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'

import { DatasetWsApi } from '../api/DatasetWsApi'
import { DatasetWsStatusMessage } from '../model/DatasetWsModels'

@Entry
@Component
struct DatasetCollectPage {
  @State labelName: string = ''
  @State cameraStatusText: string = '等待打开相机'
  @State collectStatusText: string = '请输入标签并打开相机'
  @State previewStarted: boolean = false
  @State isCollecting: boolean = false
  @State validFrames: number = 0
  @State windowSize: number = 30
  @State countdownText: string = ''

  @State surfaceId: string = ''
  @State topSafeInsetVp: number = 0
  @State bottomSafeInsetVp: number = 0

  private xComponentController: XComponentController = new XComponentController()
  private datasetWsApi: DatasetWsApi = new DatasetWsApi()

  private cameraManager?: camera.CameraManager
  private currentCamera?: camera.CameraDevice
  private currentCameraInput?: camera.CameraInput
  private currentPreviewOutput?: camera.PreviewOutput
  private currentSession?: camera.PhotoSession
  private isCameraStarting: boolean = false

  private readonly frameSendIntervalMs: number = 100
  private readonly datasetFrameFps: number = 10
  private readonly jpegQuality: number = 80
  private readonly prepareSeconds: number = 3

  private captureTimerId: number = -1
  private captureInProgress: boolean = false
  private prepareStartTime: number = 0
  private canSendFrames: boolean = false

  aboutToDisappear(): void {
    this.stopCaptureLoop()
    this.safeStopCamera()
    this.datasetWsApi.disconnect()
  }

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回失败：${JSON.stringify(err)}`)
    }
  }

  private async requestCameraPermission(): Promise<boolean> {
    const context = getContext(this) as common.UIAbilityContext
    const atManager = abilityAccessCtrl.createAtManager()
    const permissions: Array<Permissions> = ['ohos.permission.CAMERA']

    try {
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      if (!result || !result.authResults || result.authResults.length === 0) {
        return false
      }
      return result.authResults.every((item: number) => item === 0)
    } catch (error) {
      const err = error as BusinessError
      console.error(`申请相机权限失败：code=${err.code}, message=${err.message}`)
      return false
    }
  }

  private async updateWindowImmersive(enable: boolean): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(context)
      await win.setWindowLayoutFullScreen(enable)

      if (enable) {
        const systemArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
        const navArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
        this.topSafeInsetVp = px2vp(systemArea.topRect.height)
        this.bottomSafeInsetVp = px2vp(navArea.bottomRect.height)
      } else {
        this.topSafeInsetVp = 0
        this.bottomSafeInsetVp = 0
      }
    } catch (error) {
      console.error(`更新沉浸式布局失败：${JSON.stringify(error)}`)
      this.topSafeInsetVp = 0
      this.bottomSafeInsetVp = 0
    }
  }

  private getOverlayTopPadding(): number {
    return (this.topSafeInsetVp > 0 ? this.topSafeInsetVp : 32) + 8
  }

  private getOverlayBottomPadding(): number {
    return (this.bottomSafeInsetVp > 0 ? this.bottomSafeInsetVp : 24) + 16
  }

  private pickCameraDevice(cameraList: Array<camera.CameraDevice>): camera.CameraDevice | undefined {
    if (!cameraList || cameraList.length === 0) {
      return undefined
    }

    for (let i = 0; i < cameraList.length; i += 1) {
      if (cameraList[i].cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT) {
        return cameraList[i]
      }
    }

    return cameraList[0]
  }

  private getPortraitRatioOfProfile(profile: camera.Profile): number {
    const width = profile.size.width
    const height = profile.size.height
    const shortSide = Math.min(width, height)
    const longSide = Math.max(width, height)
    return shortSide / longSide
  }

  private async pickBestPreviewProfile(profiles: Array<camera.Profile>): Promise<camera.Profile> {
    const context = getContext(this) as common.UIAbilityContext
    const win = await window.getLastWindow(context)
    const rect = win.getWindowProperties().windowRect
    const targetRatio = rect.width / rect.height

    let bestProfile = profiles[0]
    let bestDiff = Number.MAX_VALUE

    for (let i = 0; i < profiles.length; i += 1) {
      const currentRatio = this.getPortraitRatioOfProfile(profiles[i])
      const diff = Math.abs(currentRatio - targetRatio)
      if (diff < bestDiff) {
        bestDiff = diff
        bestProfile = profiles[i]
      }
    }

    return bestProfile
  }

  private async handleSurfaceLoaded(): Promise<void> {
    try {
      this.surfaceId = this.xComponentController.getXComponentSurfaceId()
      await this.startRealCamera()
    } catch (error) {
      const err = error as BusinessError
      this.cameraStatusText = `获取预览画面失败：${err.code}`
      console.error(`获取 surfaceId 失败：code=${err.code}, message=${err.message}`)
    }
  }

  private async startRealCamera(): Promise<void> {
    if (this.isCameraStarting) {
      return
    }
    if (!this.surfaceId) {
      this.cameraStatusText = '预览画面尚未就绪'
      return
    }

    this.isCameraStarting = true
    this.previewStarted = false
    this.cameraStatusText = '正在申请相机权限'

    try {
      const granted = await this.requestCameraPermission()
      if (!granted) {
        this.cameraStatusText = '未获得相机权限'
        return
      }

      await this.safeStopCamera()

      const context = getContext(this) as common.UIAbilityContext
      this.cameraManager = camera.getCameraManager(context)

      const cameraList: Array<camera.CameraDevice> = this.cameraManager.getSupportedCameras()
      if (!cameraList || cameraList.length === 0) {
        this.cameraStatusText = '未找到可用摄像头'
        return
      }

      this.currentCamera = this.pickCameraDevice(cameraList)
      if (!this.currentCamera) {
        this.cameraStatusText = '摄像头选择失败'
        return
      }

      const outputCapability: camera.CameraOutputCapability =
        this.cameraManager.getSupportedOutputCapability(this.currentCamera, camera.SceneMode.NORMAL_PHOTO)

      if (!outputCapability.previewProfiles || outputCapability.previewProfiles.length === 0) {
        this.cameraStatusText = '当前设备没有可用预览配置'
        return
      }

      const displayProfile = await this.pickBestPreviewProfile(outputCapability.previewProfiles)

      this.xComponentController.setXComponentSurfaceSize({
        surfaceWidth: displayProfile.size.width,
        surfaceHeight: displayProfile.size.height
      })

      this.currentCameraInput = this.cameraManager.createCameraInput(this.currentCamera)
      await this.currentCameraInput.open()

      this.currentPreviewOutput = this.cameraManager.createPreviewOutput(displayProfile, this.surfaceId)

      this.currentPreviewOutput.on('frameStart', () => {
        this.previewStarted = true
        this.cameraStatusText = '预览已启动'
      })

      this.currentPreviewOutput.on('error', (previewError: BusinessError) => {
        this.cameraStatusText = `预览出错：${previewError.code}`
        console.error(`预览输出错误：code=${previewError.code}, message=${previewError.message}`)
      })

      this.currentSession = this.cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession
      this.currentSession.beginConfig()
      this.currentSession.addInput(this.currentCameraInput)
      this.currentSession.addOutput(this.currentPreviewOutput)
      await this.currentSession.commitConfig()

      const displayRotation = display.getDefaultDisplaySync().rotation * camera.ImageRotation.ROTATION_90
      const previewRotation = this.currentPreviewOutput.getPreviewRotation(displayRotation)
      this.currentPreviewOutput.setPreviewRotation(previewRotation, false)

      this.cameraStatusText = '正在启动预览'
      await this.currentSession.start()
    } catch (error) {
      const err = error as BusinessError
      this.cameraStatusText = `相机启动失败：${err.code}`
      console.error(`启动真实相机失败：code=${err.code}, message=${err.message}`)
    } finally {
      this.isCameraStarting = false
    }
  }

  private async captureCurrentFrameAsJpeg(): Promise<ArrayBuffer | null> {
    if (!this.surfaceId) {
      return null
    }

    let sourceMap: image.PixelMap | null = null
    let packer: image.ImagePacker | null = null

    try {
      sourceMap = await image.createPixelMapFromSurface(this.surfaceId)
      const info = sourceMap.getImageInfoSync()

      packer = image.createImagePacker()
      const jpegBytes = await packer.packToData(sourceMap, {
        format: 'image/jpeg',
        quality: this.jpegQuality,
        bufferSize: info.size.width * info.size.height * 4
      })

      if (jpegBytes.byteLength <= 0) {
        return null
      }

      return jpegBytes
    } catch (error) {
      console.error(`[DatasetCollectPage] capture jpeg failed: ${JSON.stringify(error)}`)
      return null
    } finally {
      try {
        if (packer !== null) {
          await packer.release()
        }
      } catch (_error) {
      }

      try {
        if (sourceMap !== null) {
          sourceMap.release()
        }
      } catch (_error) {
      }
    }
  }

  private startCaptureLoop(): void {
    this.stopCaptureLoop()
    this.captureTimerId = setInterval(() => {
      void this.captureAndSendLatestFrame()
    }, this.frameSendIntervalMs)
  }

  private stopCaptureLoop(): void {
    if (this.captureTimerId >= 0) {
      clearInterval(this.captureTimerId)
      this.captureTimerId = -1
    }
    this.captureInProgress = false
    this.canSendFrames = false
    this.countdownText = ''
  }

  private async captureAndSendLatestFrame(): Promise<void> {
    if (!this.isCollecting || !this.previewStarted || !this.surfaceId) {
      return
    }

    const elapsedMs = Date.now() - this.prepareStartTime
    const remainingMs = this.prepareSeconds * 1000 - elapsedMs
    if (remainingMs > 0) {
      const remainingSecond = Math.ceil(remainingMs / 1000)
      this.countdownText = `${remainingSecond}`
      return
    }

    this.countdownText = ''
    this.canSendFrames = true

    if (this.captureInProgress) {
      return
    }

    this.captureInProgress = true
    try {
      const jpegBytes = await this.captureCurrentFrameAsJpeg()
      if (!jpegBytes || jpegBytes.byteLength <= 0) {
        return
      }
      await this.datasetWsApi.sendFrame(jpegBytes)
    } catch (error) {
      console.error(`[DatasetCollectPage] send frame failed: ${JSON.stringify(error)}`)
    } finally {
      this.captureInProgress = false
    }
  }

  private async startDatasetCollect(): Promise<void> {
    const safeLabel = this.labelName.trim()
    if (safeLabel.length === 0) {
      this.collectStatusText = '请先输入标签，例如 hello / thanks'
      return
    }

    if (!this.previewStarted || !this.surfaceId) {
      this.collectStatusText = '相机预览尚未就绪'
      return
    }

    this.validFrames = 0
    this.windowSize = 30
    this.isCollecting = true
    this.canSendFrames = false
    this.prepareStartTime = Date.now()
    this.collectStatusText = '准备采集，请摆好动作'

    const connected = await this.datasetWsApi.connect(
      (message: DatasetWsStatusMessage) => {
        this.handleDatasetStatus(message)
      },
      (message: string) => {
        this.collectStatusText = message
      },
      () => {
        this.isCollecting = false
        this.stopCaptureLoop()
        this.collectStatusText = '采集连接已关闭'
      }
    )

    if (!connected) {
      this.isCollecting = false
      this.collectStatusText = '连接采集服务失败'
      return
    }

    const started = await this.datasetWsApi.startDataset(safeLabel, this.datasetFrameFps, this.windowSize)
    if (!started) {
      this.isCollecting = false
      this.collectStatusText = '启动采集失败'
      return
    }

    this.startCaptureLoop()
  }

  private async cancelDatasetCollect(): Promise<void> {
    this.isCollecting = false
    this.stopCaptureLoop()
    await this.datasetWsApi.cancelDataset()
    await this.datasetWsApi.disconnect()
    this.collectStatusText = '采集已取消'
    this.validFrames = 0
  }

  private handleDatasetStatus(message: DatasetWsStatusMessage): void {
    this.validFrames = message.validFrames
    this.windowSize = message.windowSize > 0 ? message.windowSize : 30

    if (message.status === 'ready') {
      this.collectStatusText = '准备中，倒计时结束后开始采集'
      return
    }

    if (message.status === 'invalid_frame') {
      this.collectStatusText = message.message.length > 0 ? message.message : '无效帧：请露出双肩和手部'
      return
    }

    if (message.status === 'collecting') {
      this.collectStatusText = `采集中：${this.validFrames}/${this.windowSize}`
      return
    }

    if (message.status === 'saved') {
      this.isCollecting = false
      this.stopCaptureLoop()
      this.collectStatusText = `保存成功：${message.label} (${this.windowSize}/${this.windowSize})`
      return
    }

    if (message.status === 'cancelled') {
      this.isCollecting = false
      this.stopCaptureLoop()
      this.collectStatusText = '采集已取消'
      return
    }
  }

  private async safeStopCamera(): Promise<void> {
    try {
      if (this.currentSession) {
        await this.currentSession.stop()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`停止会话失败：code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentPreviewOutput) {
        this.currentPreviewOutput.release()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`释放预览输出失败：code=${err.code}, message=${err.message}`)
    }

    try {
      if (this.currentCameraInput) {
        this.currentCameraInput.close()
      }
    } catch (error) {
      const err = error as BusinessError
      console.error(`关闭相机输入失败：code=${err.code}, message=${err.message}`)
    }

    this.currentSession = undefined
    this.currentPreviewOutput = undefined
    this.currentCameraInput = undefined
    this.currentCamera = undefined
    this.cameraManager = undefined
    this.previewStarted = false
  }

  @Builder
  private buildCameraPreview(): void {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: 'dataset-camera-preview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .onLoad(async () => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId()
          await this.startRealCamera()
        })
        .onDestroy(() => {
          this.safeStopCamera()
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      if (this.countdownText !== '') {
        Text(this.countdownText)
          .fontSize(96)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('rgba(0,0,0,0.35)')
          .borderRadius(64)
          .width(128)
          .height(128)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      Row() {
        Button('返回')
          .height(40)
          .onClick(() => {
            this.goBack()
          })

        Text('手机数据采集')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor('#FFFFFF')

      Column({ space: 12 }) {
        TextInput({ placeholder: '输入标签，例如 hello / thanks', text: this.labelName })
          .height(48)
          .fontSize(16)
          .onChange((value: string) => {
            this.labelName = value
          })

        Text(this.cameraStatusText)
          .fontSize(14)
          .fontColor('#667085')

        Text(this.collectStatusText)
          .fontSize(15)
          .fontColor('#111827')

        Text(`有效帧：${this.validFrames}/${this.windowSize}`)
          .fontSize(14)
          .fontColor('#2563EB')

        Row({ space: 12 }) {
          Button(this.isCollecting ? '采集中' : '开始采集')
            .layoutWeight(1)
            .height(48)
            .enabled(!this.isCollecting)
            .onClick(async () => {
              await this.startDatasetCollect()
            })

          Button('取消')
            .layoutWeight(1)
            .height(48)
            .enabled(this.isCollecting)
            .onClick(async () => {
              await this.cancelDatasetCollect()
            })
        }
        .width('100%')
      }
      .padding({ left: 16, right: 16, bottom: 12 })
      .width('100%')
      .backgroundColor('#FFFFFF')

      this.buildCameraPreview()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}