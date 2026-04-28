@Component
export struct GestureRecognitionPanel {
  /** 当前识别状态文案。 */
  @Prop recognitionStatusText: string = ''

  /** 当前动作是否已经识别成功。 */
  @Prop hasRecognitionSucceeded: boolean = false

  /** 当前实时识别模型版本名称。 */
  @Prop recognitionModelVersionName: string = ''

  /** 当前是否使用管理端发布模型。 */
  @Prop recognitionUsingPublishedModel: boolean = false

  /** 获取状态色。 */
  private getAccentColor(): string {
    return this.hasRecognitionSucceeded ? '#22C55E' : '#FFFFFF'
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 10 }) {
        Text(this.recognitionStatusText)
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.hasRecognitionSucceeded) {
          Text('完成')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor('#14532D')
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#DCFCE7')
            .borderRadius(12)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.recognitionModelVersionName.trim().length > 0) {
        Row({ space: 6 }) {
          Text('模型')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.62)')

          Text(this.recognitionModelVersionName)
            .layoutWeight(1)
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.82)')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(this.hasRecognitionSucceeded ? 'rgba(22,163,74,0.30)' : 'rgba(0,0,0,0.34)')
    .borderRadius(18)
    .border({ width: 1, color: this.hasRecognitionSucceeded ? 'rgba(187,247,208,0.72)' : 'rgba(255,255,255,0.16)' })
  }
}