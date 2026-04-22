import { router, window, display } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { camera } from '@kit.CameraKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'

import { GesturePracticePageParams } from '../model/GestureModels'
import { GestureWsApi } from '../api/GestureWsApi'
import { GestureWsResultMessage } from '../model/GestureWsModels'

import { LocalHandDetectResult, LocalHandKeyPoint, LocalHandRect } from '../model/LocalHandModels'
import { LocalHandDetectService } from '../service/LocalHandDetectService'


@Entry
@Component
struct GesturePracticePage {
  @State gestureId: number = 0
  @State chineseName: string = ''
  @State label: string = ''

  // 全屏相机层显示状态
  @State showCameraOverlay: boolean = false

  // 相机预览相关状态
  @State surfaceId: string = ''
  @State cameraStatusText: string = '等待打开相机'
  @State previewStarted: boolean = false

  // 悬浮层安全区内边距
  @State topSafeInsetVp: number = 0
  @State bottomSafeInsetVp: number = 0

  // 识别提示状态
  @State recognitionStatusText: string = '点击开始识别'
  @State isRecognizing: boolean = false
  @State hasRecognitionSucceeded: boolean = false

  // 本地手部可视化状态
  @State localHandPointsUi: Array<LocalHandKeyPoint> = []
  @State localHandBoxUi: LocalHandRect | null = null
  @State localHasHand: boolean = false
  @State localPreviewStatusText: string = '本地：未检测到手'

  // 预览区域像素尺寸
  @State overlayWidthPx: number = 0
  @State overlayHeightPx: number = 0

  // 本地检测服务
  private localHandDetectService: LocalHandDetectService = new LocalHandDetectService()

  // 本地检测节流
  private localDetecting: boolean = false
  private lastLocalDetectAt: number = 0
  private readonly localDetectIntervalMs: number = 120

  // XComponent 控制器
  private xComponentController: XComponentController = new XComponentController()

  // 相机相关对象
  private cameraManager?: camera.CameraManager
  private currentCamera?: camera.CameraDevice
  private currentCameraInput?: camera.CameraInput
  private currentPreviewOutput?: camera.PreviewOutput
  private currentSession?: camera.PhotoSession

  // 避免重复启动相机
  private isCameraStarting: boolean = false

  // WebSocket 手势识别服务
  private gestureWsApi: GestureWsApi = new GestureWsApi()

  // 帧发送节流
  private isFrameSending: boolean = false
  private readonly frameSendIntervalMs: number = 90

  // 抓帧循环
  private captureTimerId: number = -1
  private captureInProgress: boolean = false
  private pendingFrame: ArrayBuffer | null = null

  // start 初始化消息里需要的尺寸信息
  private gestureFrameWidth: number = 320
  private gestureFrameHeight: number = 240
  private readonly gestureFrameFps: number = 10
  private readonly jpegQuality: number = 80

  aboutToAppear(): void {
    this.readParams()
  }

  aboutToDisappear(): void {
    this.stopCaptureLoop()
    this.safeStopCamera()
    this.gestureWsApi.disconnect()
  }

  /**
   * 重置本地手部可视化
   */
  private resetLocalHandOverlay(): void {
    this.localHandPointsUi = []
    this.localHandBoxUi = null
    this.localHasHand = false
    this.localPreviewStatusText = '本地：未检测到手'
  }

  /**
   * 重置全部识别展示
   */
  private resetRecognitionView(): void {
    this.recognitionStatusText = '点击开始识别'
    this.hasRecognitionSucceeded = false
    this.resetLocalHandOverlay()
  }

  /**
   * 读取路由参数
   */
  private readParams(): void {
    try {
      const params = router.getParams() as GesturePracticePageParams
      if (params) {
        this.gestureId = Number(params.gestureId)
        this.chineseName = String(params.chineseName)
        this.label = String(params.label)
      }
    } catch (err) {
      console.error(`读取训练页参数失败：${JSON.stringify(err)}`)
    }
  }

  /**
   * 返回上一页
   */
  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回手势列表页失败：${JSON.stringify(err)}`)
    }
  }

  /**
   * 打开全屏相机层
   */
  private async openCameraOverlay(): Promise<void> {
    this.cameraStatusText = '等待创建预览面'
    this.previewStarted = false
    this.resetRecognitionView()
    await this.updateWindowImmersive(true)
    this.showCameraOverlay = true
  }

  /**
   * 关闭全屏相机层
   */
  private async closeCameraOverlay(): Promise<void> {
    await this.stopGestureRecognition(true)
    await this.safeStopCamera()
    this.showCameraOverlay = false
    this.surfaceId = ''
    this.previewStarted = false
    this.cameraStatusText = '等待打开相机'
    this.resetRecognitionView()
    await this.updateWindowImmersive(false)
  }

  /**
   * 运行时申请相机权限
   */
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

  /**
   * 切换窗口沉浸式布局，并同步读取上下安全区高度
   */
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

  /**
   * 顶部悬浮区 padding
   */
  private getOverlayTopPadding(): number {
    return (this.topSafeInsetVp > 0 ? this.topSafeInsetVp : 32) + 8
  }

  /**
   * 底部悬浮区 padding
   */
  private getOverlayBottomPadding(): number {
    return (this.bottomSafeInsetVp > 0 ? this.bottomSafeInsetVp : 24) + 16
  }

  /**
   * 主按钮文案
   */
  private getPrimaryButtonText(): string {
    if (this.hasRecognitionSucceeded) {
      return '重新开始'
    }
    return this.isRecognizing ? '停止识别' : '开始识别'
  }

  /**
   * 状态卡背景色
   */
  private getStatusCardBackgroundColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(34,197,94,0.34)'
    }
    return 'rgba(0,0,0,0.28)'
  }

  /**
   * 状态卡边框色
   */
  private getStatusCardBorderColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(134,239,172,0.82)'
    }
    return 'rgba(255,255,255,0.14)'
  }

  /**
   * 选择摄像头，优先前置
   */
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

  /**
   * 计算 profile 在竖屏显示下的宽高比（宽 / 高）
   */
  private getPortraitRatioOfProfile(profile: camera.Profile): number {
    const width = profile.size.width
    const height = profile.size.height
    const shortSide = Math.min(width, height)
    const longSide = Math.max(width, height)
    return shortSide / longSide
  }

  /**
   * 为显示流选择最接近屏幕比例的 profile
   */
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

  /**
   * XComponent 加载完成后获取 surfaceId 并启动相机
   */
  private async handleSurfaceLoaded(): Promise<void> {
    try {
      this.surfaceId = this.xComponentController.getXComponentSurfaceId()
      await this.startRealCamera()
    } catch (error) {
      const err = error as BusinessError
      this.cameraStatusText = `获取预览面失败：${err.code}`
      console.error(`获取 surfaceId 失败：code=${err.code}, message=${err.message}`)
    }
  }

  /**
   * 启动真实相机
   */
  private async startRealCamera(): Promise<void> {
    if (this.isCameraStarting) {
      return
    }
    if (!this.surfaceId) {
      this.cameraStatusText = '预览面尚未就绪'
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
        void this.updateOverlaySize()
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
   * 读取全屏预览区域尺寸
   */
  private async updateOverlaySize(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(context)
      const rect = win.getWindowProperties().windowRect
      this.overlayWidthPx = rect.width
      this.overlayHeightPx = rect.height
    } catch (error) {
      console.error(`读取 overlay 尺寸失败：${JSON.stringify(error)}`)
    }
  }

  /**
   * 从预览 surface 抓一帧，并编码成 JPEG
   */
  private async captureCurrentFrameAsJpeg(): Promise<ArrayBuffer | null> {
    if (!this.surfaceId) {
      return null
    }

    let sourceMap: image.PixelMap | null = null
    let packer: image.ImagePacker | null = null

    try {
      sourceMap = await image.createPixelMapFromSurface(this.surfaceId)
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

  /**
   * 开始抓帧循环
   */
  private startCaptureLoop(): void {
    this.stopCaptureLoop()

    this.captureTimerId = setInterval(() => {
      void this.captureAndSendLatestFrame()
    }, this.frameSendIntervalMs)
  }

  /**
   * 停止抓帧循环
   */
  private stopCaptureLoop(): void {
    if (this.captureTimerId >= 0) {
      clearInterval(this.captureTimerId)
      this.captureTimerId = -1
    }

    this.pendingFrame = null
    this.captureInProgress = false
    this.isFrameSending = false
  }

  /**
   * 抓取当前帧并入队
   */
  /**
   * 抓取当前帧，并分别喂给：
   * 1）本地手部检测
   * 2）远端 WebSocket 识别
   */
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

      // 先跑本地检测，不依赖识别按钮
      this.tryRunLocalHandDetection(jpegBytes)

      // 再决定是否发给后端识别
      if (this.isRecognizing && !this.hasRecognitionSucceeded) {
        this.enqueueFrame(jpegBytes)
      }
    } catch (error) {
      console.error(`[GesturePracticePage] unified frame loop error: ${JSON.stringify(error)}`)
    } finally {
      this.captureInProgress = false
    }
  }

  /**
   * 图像坐标 -> 当前全屏 overlay 坐标
   * 第一版先按等比例直接映射，后续如果边缘有轻微偏移，再补 center-crop 修正
   */
  private mapPointToUi(point: LocalHandKeyPoint): LocalHandKeyPoint {
    if (this.gestureFrameWidth <= 0 || this.gestureFrameHeight <= 0 ||
      this.overlayWidthPx <= 0 || this.overlayHeightPx <= 0) {
      return { x: 0, y: 0, score: 0 }
    }

    let uiX = point.x / this.gestureFrameWidth * this.overlayWidthPx
    let uiY = point.y / this.gestureFrameHeight * this.overlayHeightPx

    // 前置镜像
    uiX = this.overlayWidthPx - uiX

    return {
      x: px2vp(uiX),
      y: px2vp(uiY),
      score: point.score
    }
  }

  /**
   * 应用本地手部检测结果
   */
  private applyLocalHandDetectResult(result: LocalHandDetectResult): void {
    if (!result.hasHand || !result.points || result.points.length === 0) {
      this.localHasHand = false
      this.localHandPointsUi = []
      this.localHandBoxUi = null
      this.localPreviewStatusText = '本地：未检测到手'
      return
    }

    this.localHasHand = true
    this.localPreviewStatusText = '本地：已检测到手'

    this.localHandPointsUi = result.points.map((item: LocalHandKeyPoint) => {
      return this.mapPointToUi(item)
    })

    if (result.box) {
      const leftTop = this.mapPointToUi({ x: result.box.left, y: result.box.top, score: 1 })
      const rightBottom = this.mapPointToUi({
        x: result.box.left + result.box.width,
        y: result.box.top + result.box.height,
        score: 1
      })

      this.localHandBoxUi = {
        left: leftTop.x,
        top: leftTop.y,
        width: rightBottom.x - leftTop.x,
        height: rightBottom.y - leftTop.y
      }
    } else {
      this.localHandBoxUi = null
    }
  }

  /**
   * 节流执行本地手部检测
   */
  private tryRunLocalHandDetection(frame: ArrayBuffer): void {
    const now = Date.now()
    if (this.localDetecting) {
      return
    }
    if (now - this.lastLocalDetectAt < this.localDetectIntervalMs) {
      return
    }

    this.localDetecting = true
    this.lastLocalDetectAt = now

    void this.localHandDetectService.detectFromJpeg(
      frame,
      this.gestureFrameWidth,
      this.gestureFrameHeight,
      0
    ).then((result: LocalHandDetectResult) => {
      this.applyLocalHandDetectResult(result)
    }).catch((error: Object) => {
      console.error(`[GesturePracticePage] local hand detect failed: ${JSON.stringify(error)}`)
    }).finally(() => {
      this.localDetecting = false
    })
  }

  /**
   * 覆盖队列里的旧帧，只保留最新一帧
   */
  private enqueueFrame(frame: ArrayBuffer): void {
    this.pendingFrame = frame
    void this.flushPendingFrame()
  }

  /**
   * 发送队列里的最新帧
   */
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

  /**
   * 开始识别
   */
  private async startGestureRecognition(): Promise<void> {
    if (this.isRecognizing) {
      return
    }

    if (!this.previewStarted || !this.surfaceId) {
      this.recognitionStatusText = '预览未就绪'
      return
    }

    this.resetRecognitionView()
    this.isRecognizing = true
    this.recognitionStatusText = '请保持手势，等待识别（0/30）'

    const connected = await this.gestureWsApi.connect(
      (result: GestureWsResultMessage) => {
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

    // 先抓一帧，确定 start 里要发的尺寸
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
      this.gestureFrameFps
    )

    if (!started) {
      this.isRecognizing = false
      this.recognitionStatusText = '识别服务启动失败'
      await this.gestureWsApi.disconnect()
      return
    }

    this.enqueueFrame(firstFrame)
  }

  /**
   * 停止识别
   * @param preserveStatus 是否保留当前提示文案
   */
  private async stopGestureRecognition(preserveStatus: boolean = false): Promise<void> {
    this.isRecognizing = false
    this.stopCaptureLoop()

    if (!preserveStatus) {
      this.resetRecognitionView()
    }

    await this.gestureWsApi.disconnect()
  }

  /**
   * 识别成功后高亮并停止
   */
  private async handleRecognitionSuccess(): Promise<void> {
    if (this.hasRecognitionSucceeded) {
      return
    }

    this.hasRecognitionSucceeded = true
    this.recognitionStatusText = '识别成功'
    await this.stopGestureRecognition(true)
  }

  /**
   * 处理识别服务返回结果
   */
  private handleGestureWsResult(result: GestureWsResultMessage): void {
    if (this.hasRecognitionSucceeded) {
      return
    }

    if (result.status === 'no_hand' || result.status === 'missing_hand') {
      this.recognitionStatusText = '没有检测到手，请把手放进画面中'
      return
    }

    if (result.status === 'warming_up') {
      const safeTotal = result.windowSize > 0 ? result.windowSize : 30
      const safeProgress = Math.max(0, Math.min(result.validFrames, safeTotal))
      this.recognitionStatusText = `请保持手势，等待识别（${safeProgress}/${safeTotal}）`
      return
    }

    if (result.status === 'predicted') {
      const recognizedLabel = result.label && result.label.length > 0 ? result.label : '未知动作'
      if (result.label === this.label) {
        void this.handleRecognitionSuccess()
      } else {
        this.recognitionStatusText = `当前是「${recognizedLabel}」，不是目标动作`
      }
      return
    }

    this.recognitionStatusText = '等待识别结果'
  }

  /**
   * 安全停止相机
   */
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

  /**
   * 顶部栏
   */
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

      Text('手势训练')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Text(this.localPreviewStatusText)
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.82)')

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private buildLocalHandOverlay(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.localHandBoxUi !== null) {
        Column()
          .width(this.localHandBoxUi.width)
          .height(this.localHandBoxUi.height)
          .border({
            width: 2,
            color: 'rgba(0,229,255,0.95)'
          })
          .backgroundColor('rgba(0,229,255,0.08)')
          .position({
            x: this.localHandBoxUi.left,
            y: this.localHandBoxUi.top
          })
      }

      ForEach(this.localHandPointsUi, (point: LocalHandKeyPoint, index: number) => {
        Column()
          .width(10)
          .height(10)
          .backgroundColor('#00E5FF')
          .borderRadius(999)
          .position({
            x: point.x - 5,
            y: point.y - 5
          })
      }, (point: LocalHandKeyPoint, index: number) => `${index}-${point.x}-${point.y}`)
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 全屏相机层
   */
  @Builder
  private buildCameraOverlay(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      // 最底层：全屏相机预览
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
      this.buildLocalHandOverlay()
      // HUD 悬浮层
      Column() {
        // 顶部区域
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Text(this.chineseName ? this.chineseName : '手势训练')
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
            Text(`目标动作：${this.label}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')

            Text(this.recognitionStatusText)
              .fontSize(15)
              .lineHeight(22)
              .fontColor('#FFFFFF')
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

        // 底部区域
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
      // 正常页面
      Column() {
        this.buildTopBar()

        Column() {
          Button('打开相机')
            .width('72%')
            .height(52)
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .borderRadius(26)
            .onClick(async () => {
              await this.openCameraOverlay()
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')

      // 全屏相机层
      if (this.showCameraOverlay) {
        this.buildCameraOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}