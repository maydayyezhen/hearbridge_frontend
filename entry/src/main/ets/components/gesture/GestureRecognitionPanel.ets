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

  /** 获取识别状态卡片背景色。 */
  private getStatusCardBackgroundColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(34,197,94,0.34)'
    }
    return 'rgba(0,0,0,0.28)'
  }

  /** 获取识别状态卡片边框色。 */
  private getStatusCardBorderColor(): string {
    if (this.hasRecognitionSucceeded) {
      return 'rgba(134,239,172,0.82)'
    }
    return 'rgba(255,255,255,0.14)'
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Text(this.recognitionStatusText)
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .lineHeight(22)

        if (this.hasRecognitionSucceeded) {
          Text('完成')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#16A34A')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .backgroundColor('#DCFCE7')
            .borderRadius(14)
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.getStatusCardBackgroundColor())
      .borderRadius(20)
      .border({ width: 1, color: this.getStatusCardBorderColor() })

      Column({ space: 4 }) {
        Text('当前识别模型')
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.66)')

        Text(this.recognitionModelVersionName)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.recognitionUsingPublishedModel ? '来自管理端发布版本' : '未确认发布状态')
          .fontSize(11)
          .fontColor(this.recognitionUsingPublishedModel ? '#BBF7D0' : 'rgba(255,255,255,0.58)')
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('rgba(0,0,0,0.24)')
      .borderRadius(16)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }
}