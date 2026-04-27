import { webview } from '@kit.ArkWeb'

/**
 * 数字人示范卡片。
 *
 * 只负责展示数字人 WebView、播放按钮、状态与错误信息。
 * 数字人播放逻辑由 GestureAvatarPlaybackService 管理。
 */
@Component
export struct GestureAvatarCard {
  /** 数字人播放状态文案。 */
  @Prop avatarStatusText: string = '数字人加载中'

  /** 数字人错误文案。 */
  @Prop avatarErrorText: string = ''

  /** 当前动作 SiGML 地址。 */
  @Prop sigmlUrl: string = ''

  /** 数字人视窗高度。 */
  @Prop avatarViewportHeight: number = 360

  /** 是否使用紧凑展示模式。 */
  @Prop compact: boolean = false

  /** 数字人 WebView 控制器。 */
  avatarController: webview.WebviewController = new webview.WebviewController()

  /** 播放回调。 */
  onPlay: () => void = () => {}

  /** 重播回调。 */
  onReplay: () => void = () => {}

  /** Web 页面加载完成回调。 */
  onPageEnd: () => void = () => {}

  build() {
    Column({ space: this.compact ? 10 : 18 }) {
      Row({ space: 10 }) {
        Column({ space: 4 }) {
          Text('数字人演示')
            .fontSize(this.compact ? 18 : 22)
            .fontWeight(FontWeight.Bold)

          Text(this.avatarStatusText)
            .fontSize(this.compact ? 12 : 14)
            .fontColor('#667085')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button('播放')
          .height(this.compact ? 34 : 42)
          .padding({ left: this.compact ? 14 : 20, right: this.compact ? 14 : 20 })
          .fontSize(this.compact ? 14 : 16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#2D6CDF')
          .fontColor('#FFFFFF')
          .borderRadius(this.compact ? 17 : 21)
          .onClick(() => {
            this.onPlay()
          })

        Button('重播')
          .height(this.compact ? 34 : 42)
          .padding({ left: this.compact ? 14 : 20, right: this.compact ? 14 : 20 })
          .fontSize(this.compact ? 14 : 16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#0F172A')
          .fontColor('#FFFFFF')
          .borderRadius(this.compact ? 17 : 21)
          .onClick(() => {
            this.onReplay()
          })
      }
      .width('100%')

      Stack({ alignContent: Alignment.Center }) {
        Web({
          src: $rawfile('sign-avatar/index.html'),
          controller: this.avatarController
        })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(true)
          .onlineImageAccess(true)
          .imageAccess(true)
          .mixedMode(MixedMode.All)
          .onPageEnd(() => {
            this.onPageEnd()
          })
          .width('100%')
          .height(this.avatarViewportHeight)

        if (this.sigmlUrl === '') {
          Text('当前资源没有可播放的 SiGML 文件')
            .fontSize(16)
            .fontColor('#475467')
            .padding(16)
        }
      }
      .width('100%')
      .height(this.avatarViewportHeight)
      .padding(0)
      .borderRadius(this.compact ? 20 : 28)
      .clip(true)
      .backgroundColor('#E9EEF9')
      .border({
        width: 1,
        color: 'rgba(148,163,184,0.20)'
      })

      if (this.avatarErrorText !== '') {
        Text(this.avatarErrorText)
          .fontSize(13)
          .fontColor('#D92D20')
          .width('100%')
      }
    }
    .width('100%')
    .padding(this.compact ? 14 : 20)
    .backgroundColor('#F7F8FA')
    .borderRadius(this.compact ? 20 : 24)
  }
}
