import { GestureRecognitionPanel } from './GestureRecognitionPanel'
import { GestureDatasetCollectPanel } from './GestureDatasetCollectPanel'
import { GestureCameraActionPanel } from './GestureCameraActionPanel'

/**
 * 手语训练相机全屏 Overlay。
 *
 * 说明：
 * 1. 保持相机画面为主体。
 * 2. 顶部只保留目标动作、编码和关闭按钮。
 * 3. 识别状态采用轻量 HUD 浮层。
 * 4. 底部只保留操作按钮。
 */
@Component
export struct GestureCameraOverlay {
  /** XComponent 控制器，由页面持有并传入，避免组件内部接管相机生命周期。 */
  xComponentController: XComponentController = new XComponentController()

  /** 顶部安全区内边距。 */
  @Prop overlayTopPadding: number = 40

  /** 底部安全区内边距。 */
  @Prop overlayBottomPadding: number = 40

  /** 相机状态文案。 */
  @Prop cameraStatusText: string = ''

  /** 相机预览是否已经启动。 */
  @Prop previewStarted: boolean = false

  /** 倒计时文案。 */
  @Prop datasetCountdownText: string = ''

  /** 当前目标动作名称。 */
  @Prop targetName: string = ''

  /** 当前目标动作编码。 */
  @Prop targetCodeLabel: string = ''

  /** 当前识别状态文案。 */
  @Prop recognitionStatusText: string = ''

  /** 当前动作是否已经识别成功。 */
  @Prop hasRecognitionSucceeded: boolean = false

  /** 当前实时识别模型版本名称。 */
  @Prop recognitionModelVersionName: string = ''

  /** 当前是否使用管理端发布模型。 */
  @Prop recognitionUsingPublishedModel: boolean = false

  /** 是否启用开发者 raw dataset 采集模式。 */
  @Prop enableDatasetCollect: boolean = false

  /** 采集状态文案。 */
  @Prop datasetStatusText: string = ''

  /** 当前有效采集帧数量。 */
  @Prop datasetValidFrames: number = 0

  /** 当前样本窗口大小。 */
  @Prop datasetWindowSize: number = 30

  /** 主按钮文案。 */
  @Prop primaryButtonText: string = '开始识别'

  /** 当前是否正在采集 raw dataset。 */
  @Prop isDatasetCollecting: boolean = false

  /** 当前是否等待确认保存采集样本。 */
  @Prop isDatasetWaitingConfirm: boolean = false

  /** XComponent 加载完成回调。 */
  onSurfaceLoaded: () => void = () => {}

  /** XComponent 销毁回调。 */
  onSurfaceDestroy: () => void = () => {}

  /** 关闭相机 Overlay 回调。 */
  onClose: () => void = () => {}

  /** 切换识别状态回调。 */
  onToggleRecognition: () => void = () => {}

  /** 开始 raw dataset 采集回调。 */
  onStartDatasetCollect: () => void = () => {}

  /** 停止 raw dataset 采集回调。 */
  onStopDatasetCollect: () => void = () => {}

  /** 确认保存 raw dataset 样本回调。 */
  onConfirmSaveDataset: () => void = () => {}

  /** 丢弃 raw dataset 样本回调。 */
  onDiscardDataset: () => void = () => {}

  /**
   * 构建相机预览。
   */
  @Builder
  private buildCameraPreview(): void {
    Stack({ alignContent: Alignment.Center }) {
      XComponent({
        id: 'gesture-camera-preview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .onLoad(() => {
          this.onSurfaceLoaded()
        })
        .onDestroy(() => {
          this.onSurfaceDestroy()
        })
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')

      if (!this.previewStarted && this.cameraStatusText.trim().length > 0) {
        Text(this.cameraStatusText)
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.72)')
      }

      if (this.datasetCountdownText !== '') {
        Text(this.datasetCountdownText)
          .fontSize(88)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width(124)
          .height(124)
          .textAlign(TextAlign.Center)
          .align(Alignment.Center)
          .backgroundColor('rgba(0,0,0,0.28)')
          .borderRadius(62)
      }
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 构建顶部 HUD。
   */
  @Builder
  private buildTopHud(): void {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.targetName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (this.targetCodeLabel.trim().length > 0) {
            Text(this.targetCodeLabel)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.72)')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(20)
            .fontColor(['#FFFFFF'])
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(0,0,0,0.30)')
        .borderRadius(20)
        .stateEffect(false)
        .onClick(() => {
          this.onClose()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      GestureRecognitionPanel({
        recognitionStatusText: this.recognitionStatusText,
        hasRecognitionSucceeded: this.hasRecognitionSucceeded,
        recognitionModelVersionName: this.recognitionModelVersionName,
        recognitionUsingPublishedModel: this.recognitionUsingPublishedModel
      })

      if (this.enableDatasetCollect) {
        GestureDatasetCollectPanel({
          datasetStatusText: this.datasetStatusText,
          datasetValidFrames: this.datasetValidFrames,
          datasetWindowSize: this.datasetWindowSize
        })
      }
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: this.overlayTopPadding,
      bottom: 0
    })
  }

  /**
   * 构建底部操作区。
   */
  @Builder
  private buildBottomActions(): void {
    Column() {
      GestureCameraActionPanel({
        primaryButtonText: this.primaryButtonText,
        hasRecognitionSucceeded: this.hasRecognitionSucceeded,
        enableDatasetCollect: this.enableDatasetCollect,
        isDatasetCollecting: this.isDatasetCollecting,
        isDatasetWaitingConfirm: this.isDatasetWaitingConfirm,
        onToggleRecognition: (): void => {
          this.onToggleRecognition()
        },
        onStartDatasetCollect: (): void => {
          this.onStartDatasetCollect()
        },
        onStopDatasetCollect: (): void => {
          this.onStopDatasetCollect()
        },
        onConfirmSaveDataset: (): void => {
          this.onConfirmSaveDataset()
        },
        onDiscardDataset: (): void => {
          this.onDiscardDataset()
        }
      })
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: 0,
      bottom: this.overlayBottomPadding
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildCameraPreview()

      Column() {
        this.buildTopHud()

        Blank()

        this.buildBottomActions()
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
}