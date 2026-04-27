import { router, window } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import { BusinessError } from '@kit.BasicServicesKit'

import { GesturePracticePageParams } from '../model/GestureModels'
import { GestureCameraOverlay } from '../components/gesture/GestureCameraOverlay'
import { GestureAvatarCard } from '../components/gesture/GestureAvatarCard'
import { GestureCameraSessionService } from '../service/gesture/GestureCameraSessionService'
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

/**
 * 手语训练页面重构版。
 *
 * 职责边界：
 * 1. 页面负责路由参数、状态编排、UI 结构和 overlay 显隐。
 * 2. 相机预览启动 / 停止交给 GestureCameraSessionService。
 * 3. 实时识别交给 GestureRecognitionSessionService。
 * 4. raw dataset 采集交给 DatasetCollectSessionService。
 * 5. 数字人播放交给 GestureAvatarPlaybackService。
 */
@Entry
@Component
struct GesturePracticePageRefactored {
  /** 当前手势资源 ID。 */
  @State gestureId: number = 0
  /** 当前手势中文名。 */
  @State chineseName: string = ''
  /** 当前手势资源编码。 */
  @State resourceCode: string = ''
  /** 当前手势 SiGML 地址。 */
  @State sigmlUrl: string = ''
  /** 当前手势封面地址。 */
  @State coverUrl: string = ''

  /** 是否显示相机全屏 overlay。 */
  @State showCameraOverlay: boolean = false
  /** XComponent surface ID。 */
  @State surfaceId: string = ''
  /** 相机状态文案。 */
  @State cameraStatusText: string = '等待打开相机'
  /** 相机预览是否已经启动。 */
  @State previewStarted: boolean = false

  /** 沉浸式顶部安全区。 */
  @State topSafeInsetVp: number = 0
  /** 沉浸式底部安全区。 */
  @State bottomSafeInsetVp: number = 0

  /** 当前识别状态文案。 */
  @State recognitionStatusText: string = '点击开始识别'
  /** 当前是否正在识别。 */
  @State isRecognizing: boolean = false
  /** 当前动作是否已经识别成功。 */
  @State hasRecognitionSucceeded: boolean = false
  /** 当前实时识别服务使用的模型版本名称。 */
  @State recognitionModelVersionName: string = '尚未建立识别会话'
  /** 当前实时识别是否使用管理端发布模型。 */
  @State recognitionUsingPublishedModel: boolean = false

  /** 是否启用开发者 raw dataset 采集模式。 */
  @StorageLink('developer.datasetCollect.enabled') enableDatasetCollect: boolean = false

  /** dataset 采集状态文案。 */
  @State datasetStatusText: string = '可在查看数字人后采集当前动作样本'
  /** 当前是否正在采集。 */
  @State isDatasetCollecting: boolean = false
  /** 当前有效采集帧数。 */
  @State datasetValidFrames: number = 0
  /** 当前采集窗口大小。 */
  @State datasetWindowSize: number = 30
  /** 采集倒计时文案。 */
  @State datasetCountdownText: string = ''
  /** 当前是否等待确认保存样本。 */
  @State isDatasetWaitingConfirm: boolean = false

  /** 数字人播放状态文案。 */
  @State avatarStatusText: string = '数字人加载中'
  /** 数字人错误文案。 */
  @State avatarErrorText: string = ''

  /** XComponent 控制器。 */
  private xComponentController: XComponentController = new XComponentController()
  /** 相机会话服务。 */
  private cameraSession: GestureCameraSessionService = new GestureCameraSessionService()
  /** 手势实时识别会话服务。 */
  private recognitionSession: GestureRecognitionSessionService = new GestureRecognitionSessionService()
  /** raw dataset 采集会话服务。 */
  private datasetCollectSession: DatasetCollectSessionService = new DatasetCollectSessionService()
  /** 数字人播放会话服务。 */
  private avatarPlaybackSession: GestureAvatarPlaybackService = new GestureAvatarPlaybackService()

  /** 手势识别帧发送间隔，100ms 对应 10FPS。 */
  private readonly frameSendIntervalMs: number = 100
  /** 当前抓帧定时器 ID。 */
  private captureTimerId: number = -1
  /** 当前是否正在抓帧，避免重入。 */
  private captureInProgress: boolean = false
  /** 最近一次抓帧宽度。 */
  private gestureFrameWidth: number = 320
  /** 最近一次抓帧高度。 */
  private gestureFrameHeight: number = 240
  /** JPEG 压缩质量。 */
  private readonly jpegQuality: number = 80
  /** 发送前是否旋转图像。 */
  private readonly shouldRotateFrameBeforeSend: boolean = true
  /** 发送前旋转角度。 */
  private readonly frameRotateDegreesBeforeSend: number = 270
  /** 发送前是否水平镜像。 */
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
    void this.safeStopCamera()
    void this.recognitionSession.disconnect()
    void this.datasetCollectSession.disconnect()
    void this.stopAvatar()
    this.avatarPlaybackSession.markPageNotReady()
  }

  /** 读取路由参数。 */
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

  /** 记录最近练习。 */
  private persistRecentPractice(): void {
    AppStorage.setOrCreate('recent.practice.id', this.gestureId)
    AppStorage.setOrCreate('recent.practice.code', this.resourceCode)
    AppStorage.setOrCreate('recent.practice.name', this.chineseName === '' ? this.resourceCode : this.chineseName)
    AppStorage.setOrCreate('recent.practice.sigmlUrl', this.sigmlUrl)
    AppStorage.setOrCreate('recent.practice.coverUrl', this.coverUrl)
  }

  /** 应用 dataset 采集状态。 */
  private applyDatasetCollectState(state: DatasetCollectSessionState): void {
    this.datasetStatusText = state.datasetStatusText
    this.isDatasetCollecting = state.isDatasetCollecting
    this.datasetValidFrames = state.datasetValidFrames
    this.datasetWindowSize = state.datasetWindowSize
    this.datasetCountdownText = state.datasetCountdownText
    this.isDatasetWaitingConfirm = state.isDatasetWaitingConfirm
  }

  /** 应用实时识别状态。 */
  private applyGestureRecognitionState(state: GestureRecognitionSessionState): void {
    this.recognitionStatusText = state.recognitionStatusText
    this.isRecognizing = state.isRecognizing
    this.hasRecognitionSucceeded = state.hasRecognitionSucceeded
    this.recognitionModelVersionName = state.recognitionModelVersionName
    this.recognitionUsingPublishedModel = state.recognitionUsingPublishedModel
  }

  /** 应用数字人播放状态。 */
  private applyAvatarPlaybackState(state: GestureAvatarPlaybackState): void {
    this.avatarStatusText = state.avatarStatusText
    this.avatarErrorText = state.avatarErrorText
  }

  /** 获取展示名称。 */
  private getDisplayName(): string {
    if (this.chineseName !== '') {
      return this.chineseName
    }
    if (this.resourceCode !== '') {
      return this.resourceCode
    }
    return '手语训练'
  }

  /** 获取目标编码展示文案。 */
  private getCodeLabel(): string {
    return this.resourceCode === '' ? '未设置' : this.resourceCode
  }

  /** 播放数字人示范。 */
  private async playAvatar(): Promise<void> {
    await this.avatarPlaybackSession.play(this.sigmlUrl)
  }

  /** 重新播放数字人示范。 */
  private async replayAvatar(): Promise<void> {
    await this.avatarPlaybackSession.replay(this.sigmlUrl)
  }

  /** 停止数字人播放。 */
  private async stopAvatar(): Promise<void> {
    await this.avatarPlaybackSession.stop()
  }

  /** 返回上一页。 */
  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回资源列表页失败：${JSON.stringify(err)}`)
    }
  }

  /** 打开相机 overlay。 */
  private async openCameraOverlay(): Promise<void> {
    this.cameraStatusText = '等待创建预览画面'
    this.previewStarted = false
    this.resetRecognitionView()
    await this.updateWindowImmersive(true)
    this.showCameraOverlay = true
  }

  /** 关闭相机 overlay。 */
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

  /** 更新沉浸式窗口状态。 */
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

  /** 获取 overlay 顶部安全区。 */
  private getOverlayTopPadding(): number {
    return (this.topSafeInsetVp > 0 ? this.topSafeInsetVp : 32) + 8
  }

  /** 获取 overlay 底部安全区。 */
  private getOverlayBottomPadding(): number {
    return (this.bottomSafeInsetVp > 0 ? this.bottomSafeInsetVp : 24) + 16
  }

  /** 重置识别状态展示。 */
  private resetRecognitionView(): void {
    this.recognitionStatusText = '请露出双肩，并让手势动作保持在画面内'
    this.hasRecognitionSucceeded = false
    this.recognitionModelVersionName = '尚未建立识别会话'
    this.recognitionUsingPublishedModel = false
  }

  /** 获取识别主按钮文案。 */
  private getPrimaryButtonText(): string {
    if (this.hasRecognitionSucceeded) {
      return '重新开始'
    }
    return this.isRecognizing ? '停止识别' : '开始识别'
  }

  /** XComponent surface 加载完成。 */
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

  /** 启动真实相机预览。 */
  private async startRealCamera(): Promise<void> {
    if (this.cameraSession.isStarting()) {
      return
    }
    if (!this.surfaceId) {
      this.cameraStatusText = '预览画面尚未就绪'
      return
    }

    this.previewStarted = false
    this.cameraStatusText = '正在申请相机权限'

    const result = await this.cameraSession.startPreview({
      context: getContext(this) as common.UIAbilityContext,
      surfaceId: this.surfaceId,
      xComponentController: this.xComponentController,
      onFrameStart: (): void => {
        this.previewStarted = true
        this.cameraStatusText = '预览已启动'
        this.startCaptureLoop()
      },
      onPreviewError: (previewError: BusinessError): void => {
        this.cameraStatusText = `预览出错：${previewError.code}`
        console.error(`预览输出错误：code=${previewError.code}, message=${previewError.message}`)
      }
    })

    if (!result.success) {
      this.previewStarted = false
    }
    this.cameraStatusText = result.statusText
  }

  /** 停止真实相机预览。 */
  private async safeStopCamera(): Promise<void> {
    await this.cameraSession.stopPreview()
    this.previewStarted = false
  }

  /** 发送前统一处理 PixelMap。 */
  private async normalizeFramePixelMapBeforeSend(sourceMap: image.PixelMap): Promise<void> {
    if (this.shouldRotateFrameBeforeSend && this.frameRotateDegreesBeforeSend !== 0) {
      await sourceMap.rotate(this.frameRotateDegreesBeforeSend)
    }

    if (this.shouldMirrorFrameBeforeSend) {
      await sourceMap.flip(true, false)
    }
  }

  /** 从当前 Surface 抓取 JPEG 帧。 */
  private async captureCurrentFrameAsJpeg(): Promise<ArrayBuffer | null> {
    if (!this.surfaceId) {
      return null
    }

    let sourceMap: image.PixelMap | null = null
    let packer: image.ImagePacker | null = null

    try {
      sourceMap = await image.createPixelMapFromSurface(this.surfaceId)
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

      return jpegBytes.byteLength > 0 ? jpegBytes : null
    } catch (error) {
      console.error(`[GesturePracticePageRefactored] capture jpeg failed: ${JSON.stringify(error)}`)
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

  /** 启动抓帧循环。 */
  private startCaptureLoop(): void {
    this.stopCaptureLoop()
    this.captureTimerId = setInterval(() => {
      void this.captureAndSendLatestFrame()
    }, this.frameSendIntervalMs)
  }

  /** 停止抓帧循环。 */
  private stopCaptureLoop(): void {
    if (this.captureTimerId >= 0) {
      clearInterval(this.captureTimerId)
      this.captureTimerId = -1
    }
    this.captureInProgress = false
    this.datasetCountdownText = ''
  }

  /** 抓取并发送最新一帧。 */
  private async captureAndSendLatestFrame(): Promise<void> {
    if (!this.surfaceId || !this.previewStarted || this.captureInProgress) {
      return
    }

    this.captureInProgress = true

    try {
      const jpegBytes = await this.captureCurrentFrameAsJpeg()
      if (!jpegBytes || jpegBytes.byteLength <= 0) {
        return
      }

      if (this.recognitionSession.canAcceptFrame()) {
        this.recognitionSession.enqueueFrame(jpegBytes)
      }

      if (this.enableDatasetCollect && this.datasetCollectSession.canAcceptFrame()) {
        this.datasetCollectSession.enqueueFrame(jpegBytes)
      }
    } catch (error) {
      console.error(`[GesturePracticePageRefactored] frame loop error: ${JSON.stringify(error)}`)
    } finally {
      this.captureInProgress = false
    }
  }

  /** 开始 raw dataset 采集。 */
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

  /** 停止 raw dataset 采集。 */
  private async stopDatasetCollect(preserveStatus: boolean = false): Promise<void> {
    await this.datasetCollectSession.stop(preserveStatus)
  }

  /** 确认保存当前待确认样本。 */
  private async confirmSaveDataset(): Promise<void> {
    await this.datasetCollectSession.confirmSave()
  }

  /** 丢弃当前待确认样本。 */
  private async discardPendingDataset(): Promise<void> {
    await this.datasetCollectSession.discardPending()
  }

  /** 开始手势实时识别。 */
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

  /** 停止手势实时识别。 */
  private async stopGestureRecognition(preserveStatus: boolean = false): Promise<void> {
    await this.recognitionSession.stop(preserveStatus)
    this.stopCaptureLoop()
  }

  /** 页面顶部栏。 */
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

  /** 目标手势信息卡片。 */
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

  /** 普通训练内容。 */
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

  /** 内容区。 */
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
