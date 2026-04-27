import { router, window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'

import { AppConfig } from '../common/constants/AppConfig'
import { GesturePracticePageParams } from '../model/GestureModels'

import { GestureCameraOverlay } from '../components/gesture/GestureCameraOverlay'
import { GestureAvatarCard } from '../components/gesture/GestureAvatarCard'
import {
  GestureRecognitionSessionService,
  GestureRecognitionSessionState
} from '../service/gesture/GestureRecognitionSessionService'
import {
  DatasetCollectSessionService,
  DatasetCollectSessionState
} from '../service/gesture/DatasetCollectSessionService'
import {
  GestureAvatarPlaybackService,
  GestureAvatarPlaybackState
} from '../service/gesture/GestureAvatarPlaybackService'

const TEXT_MAIN: string = '#11233C'
const SECONDARY_TEXT: string = '#6B7A90'
const SURFACE: string = '#FFFFFF'
const CARD_BG: string = '#F7F8FA'

@Entry
@Component
struct GesturePracticePage {
  @State gestureId: number = 0
  @State chineseName: string = ''
  @State resourceCode: string = ''
  @State sigmlUrl: string = ''
  @State coverUrl: string = ''

  @State showCameraOverlay: boolean = false
  @State surfaceId: string = ''
  @State cameraStatusText: string = '等待打开相机'
  @State previewStarted: boolean = false

  @State topSafeInsetVp: number = 0
  @State bottomSafeInsetVp: number = 0

  @State recognitionStatusText: string = '点击开始识别'
  @State isRecognizing: boolean = false
  @State hasRecognitionSucceeded: boolean = false

  /** 当前实时识别服务使用的模型版本名称。 */
  @State recognitionModelVersionName: string = '尚未建立识别会话'

  /** 当前实时识别是否使用管理端发布模型。 */
  @State recognitionUsingPublishedModel: boolean = false

  /** 是否启用开发者 raw dataset 采集模式。 */
  @StorageLink('developer.datasetCollect.enabled') enableDatasetCollect: boolean = false

  @State datasetStatusText: string = '可在查看数字人后采集当前动作样本'
  @State isDatasetCollecting: boolean = false
  @State datasetValidFrames: number = 0
  @State datasetWindowSize: number = 30
  @State datasetCountdownText: string = ''
  @State isDatasetWaitingConfirm: boolean = false

  @State avatarStatusText: string = '数字人加载中'
  @State avatarErrorText: string = ''

  private xComponentController: XComponentController = new XComponentController()

  private cameraManager?: camera.CameraManager
  private currentCamera?: camera.CameraDevice
  private currentCameraInput?: camera.CameraInput
  private currentPreviewOutput?: camera.PreviewOutput
  private currentSession?: camera.PhotoSession

  private isCameraStarting: boolean = false

  /** 手势实时识别会话服务。 */
  private recognitionSession: GestureRecognitionSessionService = new GestureRecognitionSessionService()

  /** raw dataset 采集会话服务。 */
  private datasetCollectSession: DatasetCollectSessionService = new DatasetCollectSessionService()

  /** 数字人播放会话服务。 */
  private avatarPlaybackSession: GestureAvatarPlaybackService = new GestureAvatarPlaybackService()

  /**
   * 手势识别帧发送间隔。
   *
   * 100ms 对应 10FPS。
   * 需要与训练采集 FPS、模型窗口 FPS 保持一致。
   */
  private readonly frameSendIntervalMs: number = 100

  /**
   * 上报给识别服务的帧率。
   *
   * 当前统一为 10FPS，30 帧对应 3 秒动作窗口。
   */

  private captureTimerId: number = -1
  private captureInProgress: boolean = false

  private gestureFrameWidth: number = 320
  private gestureFrameHeight: number = 240

  private readonly jpegQuality: number = 80

  /**
   * 前端发送给后端前是否旋转图像。
   *
   * 后端不再做 rotate，所以这里负责把画面整理到 MediaPipe 可直接识别的方向。
   */
  private readonly shouldRotateFrameBeforeSend: boolean = true

  /**
   * 前端发送给后端前的旋转角度。
   *
   * PixelMap.rotate(90) 表示顺时针旋转 90 度。
   * 如果后端以前使用 cv2.ROTATE_90_COUNTERCLOCKWISE 才是正确方向，
   * 那这里可能需要改成 270。
   */
  private readonly frameRotateDegreesBeforeSend: number = 270

  /**
   * 前端发送给后端前是否水平镜像。
   *
   * 目标：让发送给后端的 JPEG 与手机自拍预览的左右效果一致。
   */
  private readonly shouldMirrorFrameBeforeSend: boolean = true

  aboutToAppear(): void {
    this.recognitionSession.setOnStateChange((state: GestureRecognitionSessionState): void => {
      this.applyGestureRecognitionState(state)
    })
    this.recognitionSession.setOnSessionStopped((): void => {
      if (!this.isDatasetCollecting && !this.isDatasetWaitingConfirm) {
        this.stopCaptureLoop()
      }
    })
    this.datasetCollectSession.setOnStateChange((state: DatasetCollectSessionState): void => {
      this.applyDatasetCollectState(state)
    })
    this.avatarPlaybackSession.setOnStateChange((state: GestureAvatarPlaybackState): void => {
      this.applyAvatarPlaybackState(state)
    })
    this.readParams()
  }

  aboutToDisappear(): void {
    this.stopCaptureLoop()
    this.safeStopCamera()
    void this.recognitionSession.disconnect()
    void this.datasetCollectSession.disconnect()
    void this.stopAvatar()
    this.avatarPlaybackSession.markPageNotReady()
  }

  private readParams(): void {
    try {
      const params = router.getParams() as GesturePracticePageParams
      if (params) {
        this.gestureId = Number(params.resourceId)
        this.chineseName = String(params.chineseName)
        this.resourceCode = String(params.resourceCode)
        this.sigmlUrl = String(params.sigmlUrl)
        this.coverUrl = String(params.coverUrl)
        this.persistRecentPractice()
      }
    } catch (err) {
      console.error(`读取训练页参数失败：${JSON.stringify(err)}`)
    }
  }

  private persistRecentPractice(): void {
    AppStorage.setOrCreate('recent.practice.id', this.gestureId)
    AppStorage.setOrCreate('recent.practice.code', this.resourceCode)
    AppStorage.setOrCreate('recent.practice.name', this.chineseName === '' ? this.resourceCode : this.chineseName)
    AppStorage.setOrCreate('recent.practice.sigmlUrl', this.sigmlUrl)
    AppStorage.setOrCreate('recent.practice.coverUrl', this.coverUrl)
  }

  /**
   * 应用 raw dataset 采集会话状态。
   *
   * @param state 采集会话状态
   */
  private applyDatasetCollectState(state: DatasetCollectSessionState): void {
    this.datasetStatusText = state.datasetStatusText
    this.isDatasetCollecting = state.isDatasetCollecting
    this.datasetValidFrames = state.datasetValidFrames
    this.datasetWindowSize = state.datasetWindowSize
    this.datasetCountdownText = state.datasetCountdownText
    this.isDatasetWaitingConfirm = state.isDatasetWaitingConfirm
  }

  /**
   * 应用手势实时识别会话状态。
   *
   * @param state 识别会话状态
   */
  private applyGestureRecognitionState(state: GestureRecognitionSessionState): void {
    this.recognitionStatusText = state.recognitionStatusText
    this.isRecognizing = state.isRecognizing
    this.hasRecognitionSucceeded = state.hasRecognitionSucceeded
    this.recognitionModelVersionName = state.recognitionModelVersionName
    this.recognitionUsingPublishedModel = state.recognitionUsingPublishedModel
  }

  /**
   * 应用数字人播放状态。
   *
   * @param state 数字人播放状态
   */
  private applyAvatarPlaybackState(state: GestureAvatarPlaybackState): void {
    this.avatarStatusText = state.avatarStatusText
    this.avatarErrorText = state.avatarErrorText
  }

  private getDisplayName(): string {
    if (this.chineseName !== '') {
      return this.chineseName
    }
    if (this.resourceCode !== '') {
      return this.resourceCode
    }
    return '手语训练'
  }

  private getCodeLabel(): string {
    return this.resourceCode === '' ? '未设置' : this.resourceCode
  }

  /**
   * 播放数字人示范。
   */
  private async playAvatar(): Promise<void> {
    await this.avatarPlaybackSession.play(this.sigmlUrl)
  }

  /**
   * 重新播放数字人示范。
   */
  private async replayAvatar(): Promise<void> {
    await this.avatarPlaybackSession.replay(this.sigmlUrl)
  }

  /**
   * 停止数字人播放。
   */
  private async stopAvatar(): Promise<void> {
    await this.avatarPlaybackSession.stop()
  }

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回资源列表页失败：${JSON.stringify(err)}`)
    }
  }

  private async openCameraOverlay(): Promise<void> {
    this.cameraStatusText = '等待创建预览画面'
    this.previewStarted = false
    this.resetRecognitionView()
    await this.updateWindowImmersive(true)
    this.showCameraOverlay = true
  }

  private async closeCameraOverlay(): Promise<void> {
    await this.stopGestureRecognition(true)
    await this.stopDatasetCollect(true)
    await this.safeStopCamera()
    this.showCameraOverlay = false
    this.surfaceId = ''
    this.previewStarted = false
    this.cameraStatusText = '等待打开相机'
    this.resetRecognitionView()
    await this.updateWindowImmersive(false)
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

  private resetRecognitionView(): void {
    this.recognitionStatusText = '请露出双肩，并让手势动作保持在画面内'
    this.hasRecognitionSucceeded = false
    this.recognitionModelVersionName = '尚未建立识别会话'
    this.recognitionUsingPublishedModel = false
  }

  private getPrimaryButtonText(): string {
    if (this.hasRecognitionSucceeded) {
      return '重新开始'
    }
    return this.isRecognizing ? '停止识别' : '开始识别'
  }

  private getStatusCardBackgroundColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(34,197,94,0.34)'
    }
    return 'rgba(0,0,0,0.28)'
  }

  private getStatusCardBorderColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(134,239,172,0.82)'
    }
    return 'rgba(255,255,255,0.14)'
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
        this.startCaptureLoop()
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

  /**
   * 规范化准备发送给后端的 PixelMap。
   *
   * 注意：
   * - 后端不再 rotate / flip
   * - 这里输出的 PixelMap 必须是 MediaPipe-ready 图像
   * - 识别和采集共用这一套输出
   */
  private async normalizeFramePixelMapBeforeSend(sourceMap: image.PixelMap): Promise<void> {
    if (this.shouldRotateFrameBeforeSend && this.frameRotateDegreesBeforeSend !== 0) {
      await sourceMap.rotate(this.frameRotateDegreesBeforeSend)
    }

    if (this.shouldMirrorFrameBeforeSend) {
      // 水平镜像：horizontal = true, vertical = false
      await sourceMap.flip(true, false)
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

      // 前端负责把图像处理成后端可直接送入 MediaPipe 的状态。
      await this.normalizeFramePixelMapBeforeSend(sourceMap)

      const info = sourceMap.getImageInfoSync()

      this.gestureFrameWidth = info.size.width
      this.gestureFrameHeight = info.size.height

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
      console.error(`[GesturePracticePage] capture jpeg failed: ${JSON.stringify(error)}`)
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
    this.datasetCountdownText = ''
  }

  private async captureAndSendLatestFrame(): Promise<void> {
    if (!this.surfaceId || !this.previewStarted) {
      return
    }

    if (this.captureInProgress) {
      return
    }

    this.captureInProgress = true

    try {
      const jpegBytes = await this.captureCurrentFrameAsJpeg()
      if (!jpegBytes || jpegBytes.byteLength <= 0) {
        return
      }

      // 识别链路：发送给 /ws/gesture
      if (this.recognitionSession.canAcceptFrame()) {
        this.recognitionSession.enqueueFrame(jpegBytes)
      }

      // 采集链路：发送给 /ws/dataset
      // 注意：这里不 await，避免采集发送阻塞抓帧循环。
      if (this.enableDatasetCollect && this.datasetCollectSession.canAcceptFrame()) {
        this.datasetCollectSession.enqueueFrame(jpegBytes)
      }
    } catch (error) {
      console.error(`[GesturePracticePage] unified frame loop error: ${JSON.stringify(error)}`)
    } finally {
      this.captureInProgress = false
    }
  }

  /**
   * 开始 raw dataset 采集。
   */
  private async startDatasetCollect(): Promise<void> {
    const started = await this.datasetCollectSession.start({
      enableDatasetCollect: this.enableDatasetCollect,
      isRecognizing: this.isRecognizing,
      previewStarted: this.previewStarted,
      hasSurface: this.surfaceId !== '',
      resourceCode: this.resourceCode
    })

    if (started) {
      this.startCaptureLoop()
    }
  }

  /**
   * 停止 raw dataset 采集。
   *
   * @param preserveStatus 是否保留状态文案
   */
  private async stopDatasetCollect(preserveStatus: boolean = false): Promise<void> {
    await this.datasetCollectSession.stop(preserveStatus)
  }

  /**
   * 确认保存当前待确认样本。
   */
  private async confirmSaveDataset(): Promise<void> {
    await this.datasetCollectSession.confirmSave()
  }

  /**
   * 丢弃当前待确认样本。
   */
  private async discardPendingDataset(): Promise<void> {
    await this.datasetCollectSession.discardPending()
  }

  /**
   * 开始手势实时识别。
   */
  private async startGestureRecognition(): Promise<void> {
    const firstFrame = this.previewStarted && this.surfaceId !== ''
      ? await this.captureCurrentFrameAsJpeg()
      : null

    const started = await this.recognitionSession.start({
      isDatasetBusy: this.isDatasetCollecting || this.isDatasetWaitingConfirm,
      previewStarted: this.previewStarted,
      hasSurface: this.surfaceId !== '',
      resourceCode: this.resourceCode,
      frameWidth: this.gestureFrameWidth,
      frameHeight: this.gestureFrameHeight,
      firstFrame: firstFrame
    })

    if (started) {
      this.startCaptureLoop()
    }
  }

  /**
   * 停止手势实时识别。
   *
   * @param preserveStatus 是否保留状态文案
   */
  private async stopGestureRecognition(preserveStatus: boolean = false): Promise<void> {
    await this.recognitionSession.stop(preserveStatus)
    this.stopCaptureLoop()
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
  private buildTopBar(): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([SECONDARY_TEXT])
      }
      .width(40)
      .height(40)
      .borderRadius(14)
      .backgroundColor(SURFACE)
      .stateEffect(false)
      .onClick(() => {
        this.goBack()
      })

      Text('手语训练')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Blank()
    }
    .width('100%')
  }

  @Builder
  private buildReferenceCard(): void {
    Row({ space: 16 }) {
      if (this.coverUrl !== '') {
        Image(this.coverUrl)
          .width(120)
          .height(120)
          .borderRadius(16)
          .objectFit(ImageFit.Cover)
          .backgroundColor('#EEF2F6')
      } else {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.resourceCode === '' ? 'SIGN' : this.resourceCode)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#667085')
            .textAlign(TextAlign.Center)
        }
        .width(120)
        .height(120)
        .borderRadius(16)
        .backgroundColor('#EEF2F6')
      }

      Column({ space: 10 }) {
        Text(this.getDisplayName())
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`目标编码：${this.getCodeLabel()}`)
          .fontSize(15)
          .fontColor('#667085')

        if (this.sigmlUrl !== '') {
          Text('资源文件已就绪')
            .fontSize(14)
            .fontColor('#12B76A')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
  }

  @Builder
  private buildPracticeContent(): void {
    Scroll() {
      Column({ space: 20 }) {
        this.buildReferenceCard()
        GestureAvatarCard({
          avatarStatusText: this.avatarStatusText,
          avatarErrorText: this.avatarErrorText,
          sigmlUrl: this.sigmlUrl,
          avatarController: this.avatarPlaybackSession.getController(),
          onPlay: (): void => {
            void this.playAvatar()
          },
          onReplay: (): void => {
            void this.replayAvatar()
          },
          onPageEnd: (): void => {
            this.avatarPlaybackSession.handlePageEnd(this.sigmlUrl)
          }
        })

        Button('打开相机')
          .width('100%')
          .height(54)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .borderRadius(27)
          .backgroundColor('#111827')
          .fontColor('#FFFFFF')
          .onClick(async () => {
            await this.openCameraOverlay()
          })
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 0, right: 0, top: 6, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SURFACE)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildContentArea(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildPracticeContent()
    }
    .width('100%')
    .layoutWeight(1)
    .clip(true)
    .backgroundColor(SURFACE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      Column({ space: 16 }) {
        this.buildTopBar()
        this.buildContentArea()
      }
      .width('100%')
      .height('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 0 })
      .backgroundColor(SURFACE)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      if (this.showCameraOverlay) {
        GestureCameraOverlay({
          xComponentController: this.xComponentController,
          overlayTopPadding: this.getOverlayTopPadding(),
          overlayBottomPadding: this.getOverlayBottomPadding(),
          cameraStatusText: this.cameraStatusText,
          previewStarted: this.previewStarted,
          datasetCountdownText: this.datasetCountdownText,
          targetName: this.getDisplayName(),
          targetCodeLabel: this.getCodeLabel(),
          recognitionStatusText: this.recognitionStatusText,
          hasRecognitionSucceeded: this.hasRecognitionSucceeded,
          recognitionModelVersionName: this.recognitionModelVersionName,
          recognitionUsingPublishedModel: this.recognitionUsingPublishedModel,
          enableDatasetCollect: this.enableDatasetCollect,
          datasetStatusText: this.datasetStatusText,
          datasetValidFrames: this.datasetValidFrames,
          datasetWindowSize: this.datasetWindowSize,
          primaryButtonText: this.getPrimaryButtonText(),
          isDatasetCollecting: this.isDatasetCollecting,
          isDatasetWaitingConfirm: this.isDatasetWaitingConfirm,
          onSurfaceLoaded: (): void => {
            void this.handleSurfaceLoaded()
          },
          onSurfaceDestroy: (): void => {
            void this.safeStopCamera()
          },
          onClose: (): void => {
            void this.closeCameraOverlay()
          },
          onToggleRecognition: (): void => {
            if (this.hasRecognitionSucceeded) {
              void this.startGestureRecognition()
              return
            }

            if (this.isRecognizing) {
              void this.stopGestureRecognition(false)
            } else {
              void this.startGestureRecognition()
            }
          },
          onStartDatasetCollect: (): void => {
            void this.startDatasetCollect()
          },
          onStopDatasetCollect: (): void => {
            void this.stopDatasetCollect()
          },
          onConfirmSaveDataset: (): void => {
            void this.confirmSaveDataset()
          },
          onDiscardDataset: (): void => {
            void this.discardPendingDataset()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
