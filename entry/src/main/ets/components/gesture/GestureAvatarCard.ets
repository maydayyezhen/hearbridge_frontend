import { webview } from '@kit.ArkWeb'

const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'
const AVATAR_BG: string = '#F7FAFE'

/**
 * 数字人示范卡片。
 *
 * 说明：
 * 1. 只负责展示数字人 WebView、播放入口、状态与错误信息。
 * 2. 数字人播放逻辑由 GestureAvatarPlaybackService 管理。
 * 3. 视觉风格统一为白底线性风格，减少旧卡片堆叠感。
 */
@Component
export struct GestureAvatarCard {
  /** 数字人播放状态文案。 */
  @Prop avatarStatusText: string = '数字人加载中'

  /** 数字人错误文案。 */
  @Prop avatarErrorText: string = ''

  /** 当前动作 SiGML 地址。 */
  @Prop sigmlUrl: string = ''

  /**
   * 数字人视窗高度。
   */
  @Prop avatarViewportHeight: number = 310

  /** 是否使用紧凑展示模式。 */
  @Prop compact: boolean = true

  /** 数字人 WebView 控制器。 */
  avatarController: webview.WebviewController = new webview.WebviewController()

  /** 播放回调。 */
  onPlay: () => void = () => {}

  /** 重播回调。 */
  onReplay: () => void = () => {}

  /** Web 页面加载完成回调。 */
  onPageEnd: () => void = () => {}

  /**
   * 构建线性分割线。
   */
  @Builder
  private buildDivider(): void {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(BORDER)
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        Text('数字人演示')
          .layoutWeight(1)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Button('播放')
          .height(34)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY)
          .backgroundColor('#F7FAFE')
          .borderRadius(17)
          .border({ width: 1, color: BORDER })
          .padding({ left: 16, right: 16 })
          .stateEffect(true)
          .onClick(() => {
            this.onPlay()
          })
      }
      .width('100%')
      .padding({ top: 8, bottom: 12 })
      .alignItems(VerticalAlign.Center)

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
          Text('暂无数字人资源')
            .fontSize(15)
            .fontColor(TEXT_SUB)
            .padding(16)
        }
      }
      .width('100%')
      .height(this.avatarViewportHeight)
      .borderRadius(18)
      .clip(true)
      .backgroundColor(AVATAR_BG)
      .border({ width: 1, color: BORDER })

      if (this.avatarErrorText !== '') {
        Text(this.avatarErrorText)
          .fontSize(12)
          .fontColor('#E5484D')
          .width('100%')
          .padding({ top: 10 })
      }

      Row()
        .width('100%')
        .height(14)

      this.buildDivider()
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }
}