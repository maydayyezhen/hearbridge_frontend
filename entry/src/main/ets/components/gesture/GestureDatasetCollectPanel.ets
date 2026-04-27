@Component
export struct GestureDatasetCollectPanel {
  /** 采集状态文案。 */
  @Prop datasetStatusText: string = ''

  /** 当前有效采集帧数量。 */
  @Prop datasetValidFrames: number = 0

  /** 当前样本窗口大小。 */
  @Prop datasetWindowSize: number = 30

  build() {
    Row({ space: 10 }) {
      Text(this.datasetStatusText)
        .layoutWeight(1)
        .fontSize(13)
        .fontColor('rgba(255,255,255,0.84)')
        .lineHeight(18)

      Text(`${this.datasetValidFrames}/${this.datasetWindowSize}`)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('rgba(255,255,255,0.16)')
        .borderRadius(14)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('rgba(0,0,0,0.22)')
    .borderRadius(18)
  }
}