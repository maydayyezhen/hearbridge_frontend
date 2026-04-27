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

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Button(this.primaryButtonText)
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.hasRecognitionSucceeded ? '#16A34A' : '#2D6CDF')
          .borderRadius(18)
          .onClick(() => {
            this.onToggleRecognition()
          })

        if (this.enableDatasetCollect) {
          Button(this.isDatasetCollecting ? '采集中' : '采集样本')
            .layoutWeight(1)
            .height(48)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .backgroundColor('#F97316')
            .borderRadius(18)
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
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor(this.isDatasetWaitingConfirm ? '#16A34A' : '#6B7280')
            .borderRadius(16)
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
              .fontSize(15)
              .fontColor('#FFFFFF')
              .backgroundColor('#EF4444')
              .borderRadius(16)
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