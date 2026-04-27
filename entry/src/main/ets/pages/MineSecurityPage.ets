import { router } from '@kit.ArkUI'
import { AuthApi } from '../api/AuthApi'
import { clearAuthState } from '../common/auth/AuthStorage'

const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const SECONDARY_TEXT: string = '#6B7A90'
const DANGER: string = '#E5484D'
const BORDER: string = '#E5EAF3'
const SURFACE: string = '#FFFFFF'

/**
 * 我的 / 账号与安全页面。
 */
@Entry
@Component
struct MineSecurityPage {
  /** 当前登录 token。 */
  @StorageLink('auth.token') token: string = ''
  /** 是否正在退出登录。 */
  @State loggingOut: boolean = false
  /** 页面提示文案。 */
  @State pageTip: string = ''

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回我的页失败：${JSON.stringify(err)}`)
    }
  }

  private async handleLogout(): Promise<void> {
    if (this.loggingOut) {
      return
    }

    this.loggingOut = true
    this.pageTip = '正在退出登录...'

    try {
      if (this.token.trim().length > 0) {
        await AuthApi.logout(this.token)
      }
    } catch (_err) {
    }

    await clearAuthState(this.getUIContext().getHostContext()!)
    this.pageTip = ''
    this.loggingOut = false
    this.goBack()
  }

  @Builder
  private buildTopBar(): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([SECONDARY_TEXT])
      }
      .width(40)
      .height(40)
      .borderRadius(14)
      .backgroundColor(SURFACE)
      .stateEffect(false)
      .onClick(() => {
        this.goBack()
      })

      Text('账号与安全')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Blank()
    }
    .width('100%')
  }

  @Builder
  private buildSecurityRow(icon: Resource, title: string, isDanger: boolean, onClickAction: () => void): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor(isDanger ? '#FFF1F1' : '#EAF1FF')

        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([isDanger ? DANGER : PRIMARY])
      }
      .width(34)
      .height(34)

      Text(title)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(isDanger ? DANGER : TEXT_MAIN)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(15)
        .fontColor(['#95A7C0'])
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .onClick(() => {
      onClickAction()
    })
  }

  @Builder
  private buildSecurityContent(): void {
    Column({ space: 16 }) {
      Column({ space: 10 }) {
        this.buildSecurityRow($r('sys.symbol.lock'), '修改密码', false, () => {
          this.pageTip = '修改密码页面待接入。'
        })

        this.buildSecurityRow($r('sys.symbol.power'), this.loggingOut ? '退出中...' : '退出登录', true, () => {
          void this.handleLogout()
        })
      }
      .width('100%')
      .padding(8)
      .backgroundColor(CARD_BG)
      .borderRadius(28)
      .border({ width: 1, color: BORDER })

      if (this.pageTip.trim().length > 0) {
        Text(this.pageTip)
          .width('100%')
          .fontSize(12)
          .fontColor(TEXT_SUB)
          .padding({ left: 4, right: 4 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildContentArea(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column() {
          this.buildSecurityContent()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 0, right: 0, top: 6, bottom: 20 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(SURFACE)
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .layoutWeight(1)
    .clip(true)
    .backgroundColor(SURFACE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Column({ space: 16 }) {
      this.buildTopBar()
      this.buildContentArea()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 0 })
    .backgroundColor(SURFACE)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
