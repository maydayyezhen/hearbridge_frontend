@Component
export struct GestureCameraActionPanel {
  /** 主按钮文案。 */
  @Prop primaryButtonText: string = '开始识别'

  /** 当前动作是否已经识别成功。 */
  @Prop hasRecognitionSucceeded: boolean = false

  /** 是否启用开发者 raw dataset 采集模式。 */
  @Prop enableDatasetCollect: boolean = false

  /** 当前是否正在采集 raw dataset。 */
  @Prop isDatasetCollecting: boolean = false

  /** 当前是否等待确认保存采集样本。 */
  @Prop isDatasetWaitingConfirm: boolean = false

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

  /** 获取主按钮背景色。 */
  private getPrimaryButtonColor(): string {
    if (this.hasRecognitionSucceeded) {
      return '#22C55E'
    }
    return '#FFFFFF'
  }

  /** 获取主按钮文字色。 */
  private getPrimaryTextColor(): string {
    if (this.hasRecognitionSucceeded) {
      return '#FFFFFF'
    }
    return '#111827'
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Button(this.primaryButtonText)
          .layoutWeight(1)
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getPrimaryTextColor())
          .backgroundColor(this.getPrimaryButtonColor())
          .borderRadius(25)
          .onClick(() => {
            this.onToggleRecognition()
          })

        if (this.enableDatasetCollect) {
          Button(this.isDatasetCollecting ? '采集中' : '采集样本')
            .layoutWeight(1)
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('rgba(249,115,22,0.92)')
            .borderRadius(25)
            .enabled(!this.isDatasetCollecting && !this.isDatasetWaitingConfirm)
            .onClick(() => {
              this.onStartDatasetCollect()
            })
        }
      }
      .width('100%')

      if (this.enableDatasetCollect && (this.isDatasetCollecting || this.isDatasetWaitingConfirm)) {
        Row({ space: 10 }) {
          Button(this.isDatasetWaitingConfirm ? '保存样本' : '取消采集')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor(this.isDatasetWaitingConfirm ? 'rgba(34,197,94,0.92)' : 'rgba(107,114,128,0.88)')
            .borderRadius(22)
            .onClick(() => {
              if (this.isDatasetWaitingConfirm) {
                this.onConfirmSaveDataset()
              } else {
                this.onStopDatasetCollect()
              }
            })

          if (this.isDatasetWaitingConfirm) {
            Button('丢弃样本')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .backgroundColor('rgba(239,68,68,0.92)')
              .borderRadius(22)
              .onClick(() => {
                this.onDiscardDataset()
              })
          }
        }
        .width('100%')
      }
    }
    .width('100%')
  }
}