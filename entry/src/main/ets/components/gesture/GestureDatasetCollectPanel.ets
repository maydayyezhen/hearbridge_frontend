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
        .fontSize(12)
        .fontColor('rgba(255,255,255,0.82)')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(`${this.datasetValidFrames}/${this.datasetWindowSize}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('rgba(0,0,0,0.30)')
    .borderRadius(16)
    .border({ width: 1, color: 'rgba(255,255,255,0.14)' })
  }
}