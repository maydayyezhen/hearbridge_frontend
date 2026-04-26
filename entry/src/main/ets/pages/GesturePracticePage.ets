import { router, window, display } from '@kit.ArkUI'
import { webview } from '@kit.ArkWeb'
import { common } from '@kit.AbilityKit'
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'

import { AppConfig } from '../common/constants/AppConfig'
import { GesturePracticePageParams } from '../model/GestureModels'
import { GestureWsApi } from '../api/GestureWsApi'
import { GestureWsResultMessage } from '../model/GestureWsModels'

import { DatasetWsApi } from '../api/DatasetWsApi'
import { DatasetWsStatusMessage } from '../model/DatasetWsModels'


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

  @State datasetStatusText: string = '可在查看数字人后采集当前动作样本'
  @State isDatasetCollecting: boolean = false
  @State datasetValidFrames: number = 0
  @State datasetWindowSize: number = 30
  @State datasetCountdownText: string = ''
  @State isDatasetWaitingConfirm: boolean = false

  @State avatarStatusText: string = '数字人加载中'
  @State avatarErrorText: string = ''

  private xComponentController: XComponentController = new XComponentController()
  private avatarController: webview.WebviewController = new webview.WebviewController()
  private avatarPageReady: boolean = false

  private cameraManager?: camera.CameraManager
  private currentCamera?: camera.CameraDevice
  private currentCameraInput?: camera.CameraInput
  private currentPreviewOutput?: camera.PreviewOutput
  private currentSession?: camera.PhotoSession

  private isCameraStarting: boolean = false

  private gestureWsApi: GestureWsApi = new GestureWsApi()

  private datasetWsApi: DatasetWsApi = new DatasetWsApi()

  private isFrameSending: boolean = false

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

  /** 识别链路待发送的最新帧。 */
  private pendingFrame: ArrayBuffer | null = null

  /** 采集链路待发送的最新帧。 */
  private pendingDatasetFrame: ArrayBuffer | null = null

  /** 采集链路当前是否正在发送帧。 */
  private isDatasetFrameSending: boolean = false

  private gestureFrameWidth: number = 320
  private gestureFrameHeight: number = 240

  /**
   * 上报给识别服务的帧率。
   *
   * 当前统一为 10FPS，30 帧对应 3 秒动作窗口。
   */
  private readonly gestureFrameFps: number = 10

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

  /** raw dataset 采集帧率。 */
  private readonly datasetFrameFps: number = 10

  /** raw dataset 单个样本窗口大小。 */
  private readonly datasetWindowFrameCount: number = 30

  /** 点击采集后给用户准备动作的倒计时秒数。 */
  private readonly datasetPrepareSeconds: number = 3

  /** raw dataset 采集倒计时开始时间戳。 */
  private datasetPrepareStartTime: number = 0

  aboutToAppear(): void {
    this.readParams()
  }

  aboutToDisappear(): void {
    this.stopCaptureLoop()
    this.safeStopCamera()
    this.gestureWsApi.disconnect()
    this.datasetWsApi.disconnect()
    void this.stopAvatar()
    this.avatarPageReady = false
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

  private buildAvatarBootstrapScript(playNow: boolean): string {
    const payload = JSON.stringify({
      sigmlUrl: this.sigmlUrl,
      cwaBase: AppConfig.buildRuntimeBaseUrl(),
      sigmlBase: AppConfig.buildDemoSigmlBaseUrl(),
      avJARBase: AppConfig.buildAvatarJarBaseUrl()
    })

    const playScript = playNow ? "window.playCurrentSign && window.playCurrentSign();" : ''
    return `window.setAvatarConfig && window.setAvatarConfig(${payload}); ${playScript} 'ok';`
  }

  private async syncAvatar(playNow: boolean): Promise<void> {
    if (!this.avatarPageReady) {
      this.avatarStatusText = '数字人画面还在加载'
      return
    }

    if (this.sigmlUrl === '') {
      this.avatarStatusText = '当前资源没有可播放的 SiGML 文件'
      return
    }

    try {
      await this.avatarController.runJavaScript(this.buildAvatarBootstrapScript(playNow))
      this.avatarErrorText = ''
      this.avatarStatusText = playNow ? '数字人正在播放' : '数字人已就绪'
    } catch (err) {
      this.avatarErrorText = `同步数字人配置失败：${JSON.stringify(err)}`
      this.avatarStatusText = '数字人加载失败'
      console.error(this.avatarErrorText)
    }
  }

  private async playAvatar(): Promise<void> {
    await this.syncAvatar(true)
  }

  private async replayAvatar(): Promise<void> {
    if (!this.avatarPageReady) {
      this.avatarStatusText = '数字人画面还在加载'
      return
    }

    if (this.sigmlUrl === '') {
      this.avatarStatusText = '当前资源没有可播放的 SiGML 文件'
      return
    }

    try {
      await this.avatarController.runJavaScript("window.replayCurrentSign && window.replayCurrentSign(); 'ok';")
      this.avatarErrorText = ''
      this.avatarStatusText = '数字人已重新播放'
    } catch (err) {
      this.avatarErrorText = `重播数字人失败：${JSON.stringify(err)}`
      this.avatarStatusText = '数字人重播失败'
      console.error(this.avatarErrorText)
    }
  }

  private async stopAvatar(): Promise<void> {
    if (!this.avatarPageReady) {
      return
    }

    try {
      await this.avatarController.runJavaScript("window.stopCurrentSign && window.stopCurrentSign(); 'ok';")
    } catch (err) {
      console.error(`停止数字人播放失败：${JSON.stringify(err)}`)
    }
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

    this.pendingFrame = null
    this.pendingDatasetFrame = null

    this.captureInProgress = false
    this.isFrameSending = false
    this.isDatasetFrameSending = false

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
      if (this.isRecognizing && !this.hasRecognitionSucceeded) {
        this.enqueueFrame(jpegBytes)
      }

      // 采集链路：发送给 /ws/dataset
      // 注意：这里不 await，避免采集发送阻塞抓帧循环。
      if (this.isDatasetCollecting) {
        this.enqueueDatasetFrame(jpegBytes)
      }
    } catch (error) {
      console.error(`[GesturePracticePage] unified frame loop error: ${JSON.stringify(error)}`)
    } finally {
      this.captureInProgress = false
    }
  }

  /**
   * 将采集链路的最新帧放入待发送槽位。
   *
   * 设计目标：
   * - 不阻塞抓帧循环
   * - 如果发送慢，只保留最新帧
   * - 旧帧会被自然覆盖，避免采集画面卡顿
   */
  private enqueueDatasetFrame(frame: ArrayBuffer): void {
    this.pendingDatasetFrame = frame
    void this.flushPendingDatasetFrame()
  }

  /**
   * 发送采集链路中最新的一帧。
   *
   * 与识别链路类似，采用“最新帧优先”策略：
   * - 同一时间只发送一帧
   * - 发送期间来了新帧，只保留最新的一帧
   * - 当前帧发完后，如果还有 pending 帧，再继续发
   */
  private async flushPendingDatasetFrame(): Promise<void> {
    if (this.isDatasetFrameSending || this.pendingDatasetFrame === null) {
      return
    }

    if (!this.isDatasetCollecting || this.isDatasetWaitingConfirm) {
      this.pendingDatasetFrame = null
      return
    }

    const frame = this.pendingDatasetFrame
    this.pendingDatasetFrame = null
    this.isDatasetFrameSending = true

    try {
      await this.handleDatasetFrame(frame)
    } finally {
      this.isDatasetFrameSending = false

      if (this.pendingDatasetFrame !== null) {
        void this.flushPendingDatasetFrame()
      }
    }
  }

  private async handleDatasetFrame(jpegBytes: ArrayBuffer): Promise<void> {
    if (!this.isDatasetCollecting || this.isDatasetWaitingConfirm) {
      return
    }

    const elapsedMs = Date.now() - this.datasetPrepareStartTime
    const remainingMs = this.datasetPrepareSeconds * 1000 - elapsedMs

    if (remainingMs > 0) {
      const remainingSecond = Math.ceil(remainingMs / 1000)
      this.datasetCountdownText = `${remainingSecond}`
      this.datasetStatusText = `准备采集：${remainingSecond} 秒后开始`
      return
    }

    this.datasetCountdownText = ''

    if (!this.datasetWsApi.isConnected()) {
      return
    }

    await this.datasetWsApi.sendFrame(jpegBytes)
  }

  private async startDatasetCollect(): Promise<void> {
    if (this.isDatasetCollecting) {
      return
    }

    if (this.isRecognizing) {
      this.datasetStatusText = '请先停止识别，再采集样本'
      return
    }

    if (!this.previewStarted || !this.surfaceId) {
      this.datasetStatusText = '相机预览尚未就绪'
      return
    }

    if (this.resourceCode === '') {
      this.datasetStatusText = '当前动作编码为空，无法采集'
      return
    }

    this.datasetValidFrames = 0
    this.datasetWindowSize = this.datasetWindowFrameCount
    this.datasetCountdownText = ''
    this.isDatasetWaitingConfirm = false
    this.datasetPrepareStartTime = Date.now()
    this.isDatasetCollecting = true
    this.datasetStatusText = `准备采集当前动作：${this.resourceCode}`

    const connected = await this.datasetWsApi.connect(
      (message: DatasetWsStatusMessage) => {
        this.handleDatasetStatus(message)
      },
      (message: string) => {
        this.datasetStatusText = message
      },
      () => {
        this.isDatasetCollecting = false
        this.datasetCountdownText = ''
        this.datasetStatusText = '采集连接已关闭'
      }
    )

    if (!connected) {
      this.isDatasetCollecting = false
      this.datasetStatusText = '连接采集服务失败'
      return
    }

    const started = await this.datasetWsApi.startDataset(
      this.resourceCode,
      this.datasetFrameFps,
      this.datasetWindowFrameCount
    )

    if (!started) {
      this.isDatasetCollecting = false
      this.datasetStatusText = '启动采集失败'
      await this.datasetWsApi.disconnect()
      return
    }

    this.startCaptureLoop()
  }

  private async stopDatasetCollect(preserveStatus: boolean = false): Promise<void> {
    const wasCollecting = this.isDatasetCollecting
    const wasWaitingConfirm = this.isDatasetWaitingConfirm

    this.isDatasetCollecting = false
    this.isDatasetWaitingConfirm = false
    this.datasetCountdownText = ''

    this.pendingDatasetFrame = null
    this.isDatasetFrameSending = false

    if (wasCollecting || wasWaitingConfirm) {
      await this.datasetWsApi.cancelDataset()
    }

    await this.datasetWsApi.disconnect()

    if (!preserveStatus) {
      this.datasetStatusText = wasWaitingConfirm ? '待确认样本已取消' : '采集已取消'
      this.datasetValidFrames = 0
    }
  }

  private async confirmSaveDataset(): Promise<void> {
    if (!this.isDatasetWaitingConfirm) {
      return
    }

    const success = await this.datasetWsApi.saveDataset()
    if (!success) {
      this.datasetStatusText = '确认保存失败：采集服务未连接'
    }
  }

  private async discardPendingDataset(): Promise<void> {
    if (!this.isDatasetWaitingConfirm) {
      return
    }

    const success = await this.datasetWsApi.discardDataset()
    if (!success) {
      this.isDatasetWaitingConfirm = false
      this.datasetValidFrames = 0
      this.datasetStatusText = '丢弃失败：采集服务未连接，已在前端清空状态'
      await this.datasetWsApi.disconnect()
    }
  }

  private handleDatasetStatus(message: DatasetWsStatusMessage): void {
    this.datasetValidFrames = message.validFrames
    this.datasetWindowSize = message.windowSize > 0 ? message.windowSize : this.datasetWindowFrameCount

    if (message.status === 'ready') {
      this.datasetStatusText = '采集服务已就绪，请摆好动作'
      return
    }

    if (message.status === 'invalid_frame') {
      this.datasetStatusText = message.message.length > 0 ? message.message : '无效帧：请露出双肩和手部'
      return
    }

    if (message.status === 'collecting') {
      this.datasetStatusText = `采集中：${this.datasetValidFrames}/${this.datasetWindowSize}`
      return
    }

    if (message.status === 'ready_to_save') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = true
      this.datasetCountdownText = ''

      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false

      this.datasetValidFrames = this.datasetWindowSize
      this.datasetStatusText = message.message.length > 0 ? message.message : '样本采集完成，请确认是否保存'
      return
    }

    if (message.status === 'saved') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetValidFrames = this.datasetWindowSize
      this.datasetStatusText = `采集保存成功：${message.label}`
      this.datasetWsApi.disconnect()
      return
    }

    if (message.status === 'discarded') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetValidFrames = 0
      this.datasetStatusText = '样本已丢弃，可重新采集'
      this.datasetWsApi.disconnect()
      return
    }

    if (message.status === 'cancelled') {
      this.isDatasetCollecting = false
      this.isDatasetWaitingConfirm = false
      this.datasetCountdownText = ''
      this.pendingDatasetFrame = null
      this.isDatasetFrameSending = false
      this.datasetStatusText = '采集已取消'
      return
    }
  }



  private enqueueFrame(frame: ArrayBuffer): void {
    this.pendingFrame = frame
    void this.flushPendingFrame()
  }

  private async flushPendingFrame(): Promise<void> {
    if (this.isFrameSending || this.pendingFrame === null) {
      return
    }

    if (!this.isRecognizing || this.hasRecognitionSucceeded) {
      return
    }

    if (!this.gestureWsApi.isConnected() || !this.gestureWsApi.isStarted()) {
      return
    }

    const frame = this.pendingFrame
    this.pendingFrame = null
    this.isFrameSending = true

    try {
      await this.gestureWsApi.sendFrame(frame)
    } finally {
      this.isFrameSending = false
      if (this.pendingFrame !== null) {
        void this.flushPendingFrame()
      }
    }
  }

  private async startGestureRecognition(): Promise<void> {
    if (this.isRecognizing) {
      return
    }

    if (this.isDatasetCollecting || this.isDatasetWaitingConfirm) {
      this.recognitionStatusText = '正在采集或等待保存样本，请先处理当前样本'
      return
    }

    if (!this.previewStarted || !this.surfaceId) {
      this.recognitionStatusText = '预览尚未就绪'
      return
    }

    this.resetRecognitionView()
    this.isRecognizing = true
    this.recognitionStatusText = '请露出双肩，并将手势保持在画面内（0/30）'

    const connected = await this.gestureWsApi.connect(
      (result: GestureWsResultMessage) => {
        console.warn(
          `[HB_MODEL_VERSION][page] modelVersionName=${result.modelVersionName}, usingPublishedModel=${result.usingPublishedModel}`
        )
        console.info(
          `[GesturePracticePage] result modelVersionName=${result.modelVersionName}, usingPublishedModel=${result.usingPublishedModel}`
        )

        this.recognitionModelVersionName =
          result.modelVersionName && result.modelVersionName.length > 0
            ? result.modelVersionName
            : 'default'

        this.recognitionUsingPublishedModel = result.usingPublishedModel
        this.recognitionModelVersionName =
          result.modelVersionName && result.modelVersionName.length > 0
            ? result.modelVersionName
            : 'default'

        this.recognitionUsingPublishedModel = result.usingPublishedModel
        this.handleGestureWsResult(result)
      },
      (_message: string) => {
        this.recognitionStatusText = '识别服务异常'
      },
      () => {
        this.isRecognizing = false
        this.stopCaptureLoop()
        if (!this.hasRecognitionSucceeded) {
          this.recognitionStatusText = '识别已停止'
        }
      }
    )

    if (!connected) {
      this.isRecognizing = false
      this.recognitionStatusText = '识别服务连接失败'
      return
    }

    const firstFrame = await this.captureCurrentFrameAsJpeg()
    if (!firstFrame || this.gestureFrameWidth <= 0 || this.gestureFrameHeight <= 0) {
      this.isRecognizing = false
      this.recognitionStatusText = '首帧抓取失败'
      await this.gestureWsApi.disconnect()
      return
    }

    const started = await this.gestureWsApi.startSession(
      this.gestureFrameWidth,
      this.gestureFrameHeight,
      this.gestureFrameFps,
    )

    if (!started) {
      this.isRecognizing = false
      this.recognitionStatusText = '识别服务启动失败'
      await this.gestureWsApi.disconnect()
      return
    }

    this.enqueueFrame(firstFrame)
  }

  private async stopGestureRecognition(preserveStatus: boolean = false): Promise<void> {
    this.isRecognizing = false
    this.stopCaptureLoop()

    if (!preserveStatus) {
      this.resetRecognitionView()
    }

    await this.gestureWsApi.disconnect()
  }

  private async handleRecognitionSuccess(): Promise<void> {
    if (this.hasRecognitionSucceeded) {
      return
    }

    this.hasRecognitionSucceeded = true
    this.recognitionStatusText = '识别成功'
    await this.stopGestureRecognition(true)
  }

  private handleGestureWsResult(result: GestureWsResultMessage): void {
    if (this.hasRecognitionSucceeded) {
      return
    }

    if (result.status === 'no_hand' || result.status === 'missing_hand') {
      this.recognitionStatusText = '未检测到有效动作，请露出双肩并将手势放入画面内'
      return
    }

    if (result.status === 'warming_up') {
      const safeTotal = result.windowSize > 0 ? result.windowSize : 30
      const safeProgress = Math.max(0, Math.min(result.validFrames, safeTotal))
      this.recognitionStatusText = `请保持上半身和手势在画面内（${safeProgress}/${safeTotal}）`
      return
    }

    if (result.status === 'predicted') {
      const recognizedLabel = result.label && result.label.length > 0 ? result.label : '未知动作'
      if (result.label === this.resourceCode) {
        void this.handleRecognitionSuccess()
      } else {
        this.recognitionStatusText = `当前识别为“${recognizedLabel}”，请调整动作后重试`
      }
      return
    }

    this.recognitionStatusText = '等待识别结果'
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
    Row() {
      Button('返回')
        .fontSize(16)
        .height(40)
        .backgroundColor('#F3F4F6')
        .fontColor('#222222')
        .borderRadius(20)
        .onClick(() => {
          this.goBack()
        })

      Text('手语训练')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
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
    .backgroundColor('#F7F8FA')
    .borderRadius(20)
  }

  @Builder
  private buildAvatarCard(): void {
    Column({ space: 18 }) {
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text('数字人演示')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)

          Text(this.avatarStatusText)
            .fontSize(14)
            .fontColor('#667085')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('播放')
          .height(42)
          .padding({ left: 20, right: 20 })
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#2D6CDF')
          .fontColor('#FFFFFF')
          .borderRadius(21)
          .onClick(() => {
            void this.playAvatar()
          })

        Button('重播')
          .height(42)
          .padding({ left: 20, right: 20 })
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#0F172A')
          .fontColor('#FFFFFF')
          .borderRadius(21)
          .onClick(() => {
            void this.replayAvatar()
          })
      }
      .width('100%')

      Stack({ alignContent: Alignment.Center }) {
        Web({
          src: $rawfile('sign-avatar/index.html'),
          controller: this.avatarController
        })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(true)
          .onlineImageAccess(true)
          .imageAccess(true)
          .mixedMode(MixedMode.All)
          .onPageEnd((_event) => {
            this.avatarPageReady = true
            this.avatarStatusText = this.sigmlUrl === '' ? '当前资源没有可播放的 SiGML 文件' : '数字人已就绪'
            void this.syncAvatar(false)
          })
          .width('100%')
          .height(360)

        if (this.sigmlUrl === '') {
          Text('当前资源没有可播放的 SiGML 文件')
            .fontSize(16)
            .fontColor('#475467')
            .padding(16)
        }
      }
      .width('100%')
      .height(360)
      .padding(0)
      .borderRadius(28)
      .clip(true)
      .backgroundColor('#E9EEF9')
      .border({
        width: 1,
        color: 'rgba(148,163,184,0.20)'
      })

      if (this.avatarErrorText !== '') {
        Text(this.avatarErrorText)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#F7F8FA')
    .borderRadius(24)
  }


  @Builder
  private buildCameraOverlay(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      XComponent({
        id: 'gesture-camera-preview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .onLoad(async () => {
          await this.handleSurfaceLoaded()
        })
        .onDestroy(() => {
          this.safeStopCamera()
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')



      if (this.datasetCountdownText !== '') {
        Text(this.datasetCountdownText)
          .fontSize(96)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('rgba(0,0,0,0.35)')
          .borderRadius(64)
          .width(128)
          .height(128)
          .textAlign(TextAlign.Center)
          .align(Alignment.Center)
      }




      Column() {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Text(this.getDisplayName())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Blank()

            Button('关闭')
              .height(40)
              .padding({ left: 18, right: 18 })
              .fontSize(16)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(0,0,0,0.38)')
              .borderRadius(20)
              .onClick(async () => {
                await this.closeCameraOverlay()
              })
          }
          .width('100%')

          Column({ space: 10 }) {
            Text(`目标动作：${this.getDisplayName()}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')

            Text(`目标编码：${this.getCodeLabel()}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')

            Text(`相机状态：${this.cameraStatusText}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')

            Text(this.recognitionStatusText)
              .fontSize(15)
              .lineHeight(22)
              .fontColor('#FFFFFF')
            Text(`当前模型：${this.recognitionModelVersionName}${this.recognitionUsingPublishedModel ? '（已发布）' : ''}`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.72)')
              .margin({ top: 6 })
            Text(`采集状态：${this.datasetStatusText}`)
              .fontSize(14)
              .lineHeight(20)
              .fontColor('rgba(255,255,255,0.90)')

            Text(`采集进度：${this.datasetValidFrames}/${this.datasetWindowSize}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.getStatusCardBackgroundColor())
          .borderRadius(16)
          .border({
            width: 1,
            color: this.getStatusCardBorderColor()
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 16,
          right: 16,
          top: this.getOverlayTopPadding(),
          bottom: 0
        })

        Blank()

        Column() {
          Button(this.getPrimaryButtonText())
            .width('100%')
            .height(54)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(this.hasRecognitionSucceeded ? 'rgba(34,197,94,0.55)' : 'rgba(255,255,255,0.22)')
            .borderRadius(27)
            .onClick(async () => {
              if (this.hasRecognitionSucceeded) {
                await this.startGestureRecognition()
                return
              }

              if (this.isRecognizing) {
                await this.stopGestureRecognition(false)
              } else {
                await this.startGestureRecognition()
              }
            })

          Row({ space: 12 }) {
            Button(this.isDatasetCollecting ? '采集中' : '采集样本')
              .layoutWeight(1)
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor(this.isDatasetCollecting ? 'rgba(148,163,184,0.82)' : 'rgba(16,185,129,0.92)')
              .borderRadius(24)
              .enabled(!this.isDatasetCollecting && !this.isDatasetWaitingConfirm && !this.isRecognizing)
              .onClick(async () => {
                await this.startDatasetCollect()
              })

            Button('取消采集')
              .layoutWeight(1)
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(239,68,68,0.86)')
              .borderRadius(24)
              .enabled(this.isDatasetCollecting || this.isDatasetWaitingConfirm)
              .onClick(async () => {
                await this.stopDatasetCollect()
              })
          }
          .width('100%')
          .margin({ top: 12 })
          if (this.isDatasetWaitingConfirm) {
            Row({ space: 12 }) {
              Button('保存样本')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .backgroundColor('rgba(37,99,235,0.92)')
                .borderRadius(24)
                .onClick(async () => {
                  await this.confirmSaveDataset()
                })

              Button('丢弃样本')
                .layoutWeight(1)
                .height(48)
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .backgroundColor('rgba(107,114,128,0.92)')
                .borderRadius(24)
                .onClick(async () => {
                  await this.discardPendingDataset()
                })
            }
            .width('100%')
            .margin({ top: 12 })
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: 16,
          right: 16,
          top: 0,
          bottom: this.getOverlayBottomPadding()
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  build() {
    Stack() {
      Column() {
        this.buildTopBar()

        Scroll() {
          Column({ space: 20 }) {
            this.buildReferenceCard()
            this.buildAvatarCard()

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
          .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      if (this.showCameraOverlay) {
        this.buildCameraOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
