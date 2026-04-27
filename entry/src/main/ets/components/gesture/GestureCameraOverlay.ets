import { GestureRecognitionPanel } from './GestureRecognitionPanel'
import { GestureDatasetCollectPanel } from './GestureDatasetCollectPanel'
import { GestureCameraActionPanel } from './GestureCameraActionPanel'

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
   * 获取顶部有意义内容保护距离。
   *
   * 说明：
   * 相机预览画面可以铺进系统安全区，但顶部标题、关闭按钮、识别面板不能压进状态栏。
   * 真机上 avoidArea 可能偏小或临时为 0，因此这里加最小保护值。
   */
  private getProtectedTopPadding(): number {
    return Math.max(this.overlayTopPadding, 56)
  }

  /**
   * 获取底部有意义内容保护距离。
   *
   * 说明：
   * 底部操作按钮不能压进手势条 / 导航指示区，因此这里加最小保护值。
   */
  private getProtectedBottomPadding(): number {
    return Math.max(this.overlayBottomPadding, 64)
  }

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

      if (!this.previewStarted) {
        Text(this.cameraStatusText)
          .fontSize(16)
          .fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor('rgba(0,0,0,0.48)')
          .borderRadius(18)
      }

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
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      this.buildCameraPreview()

      Column() {
        Column({ space: 10 }) {
          Row({ space: 12 }) {
            Text(this.targetName)
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
              .onClick(() => {
                this.onClose()
              })
          }
          .width('100%')

          Column({ space: 10 }) {
            Text(`目标动作：${this.targetName}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')

            Text(`目标编码：${this.targetCodeLabel}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')

            Text(`相机状态：${this.cameraStatusText}`)
              .fontSize(14)
              .fontColor('rgba(255,255,255,0.82)')

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
          .padding(12)
          .backgroundColor(this.hasRecognitionSucceeded ? 'rgba(34,197,94,0.34)' : 'rgba(0,0,0,0.28)')
          .borderRadius(16)
          .border({
            width: 1,
            color: this.hasRecognitionSucceeded ? 'rgba(134,239,172,0.82)' : 'rgba(255,255,255,0.14)'
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 16,
          right: 16,
          top: this.getProtectedTopPadding(),
          bottom: 0
        })

        Blank()

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
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: 16,
          right: 16,
          top: 0,
          bottom: this.getProtectedBottomPadding()
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
}
