import common from '@ohos.app.ability.common'
import { router } from '@kit.ArkUI'
import { AuthApi } from '../api/AuthApi'
import { clearAuthState } from '../common/auth/AuthStorage'

const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const SECONDARY_TEXT: string = '#6B7A90'
const DANGER: string = '#E5484D'
const BORDER: string = '#E5EAF3'
const SURFACE: string = '#FFFFFF'

/**
 * 我的 / 账号与安全页面。
 *
 * 说明：
 * 1. 页面只保留安全功能入口。
 * 2. 修改密码跳转到独立页面。
 * 3. 退出登录仍在本页面处理。
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

  /**
   * 获取当前 Ability 上下文。
   */
  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

  /**
   * 返回上一页。
   */
  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回我的页失败：${JSON.stringify(err)}`)
    }
  }

  /**
   * 打开修改密码页面。
   */
  private openPasswordPage(): void {
    router.pushUrl({
      url: 'pages/MinePasswordPage'
    }).catch((err: Object) => {
      console.error(`打开修改密码页失败：${JSON.stringify(err)}`)
    })
  }

  /**
   * 处理退出登录。
   */
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

    await clearAuthState(this.getAbilityContext())
    this.pageTip = ''
    this.loggingOut = false
    this.goBack()
  }

  /**
   * 构建顶部栏。
   */
  @Builder
  private buildTopBar(): void {
    Row({ space: 10 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([SECONDARY_TEXT])
      }
      .width(36)
      .height(36)
      .borderRadius(18)
      .backgroundColor(Color.Transparent)
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
    .padding({ top: 2, bottom: 8 })
  }

  /**
   * 构建线性分割线。
   */
  @Builder
  private buildDivider(leftMargin: number = 0): void {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(BORDER)
      .margin({ left: leftMargin })
  }

  /**
   * 构建安全入口行。
   */
  @Builder
  private buildSecurityRow(
    icon: Resource,
    title: string,
    isDanger: boolean,
    showDivider: boolean,
    onClickAction: () => void
  ): void {
    Column() {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(icon)
            .fontSize(18)
            .fontColor([isDanger ? DANGER : PRIMARY])
        }
        .width(40)
        .height(40)
        .borderRadius(14)
        .backgroundColor(isDanger ? '#FFF1F1' : PRIMARY_SOFT)

        Text(title)
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(isDanger ? DANGER : TEXT_MAIN)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(15)
          .fontColor(['#95A7C0'])
      }
      .width('100%')
      .padding({ top: 16, bottom: 16 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        onClickAction()
      })

      if (showDivider) {
        this.buildDivider(54)
      }
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  /**
   * 构建内容区。
   */
  @Builder
  private buildContentArea(): void {
    Scroll() {
      Column({ space: 16 }) {
        Column({ space: 0 }) {
          this.buildSecurityRow(
            $r('sys.symbol.lock'),
            '修改密码',
            false,
            true,
            () => {
              this.openPasswordPage()
            }
          )

          this.buildSecurityRow(
            $r('sys.symbol.power'),
            this.loggingOut ? '退出中...' : '退出登录',
            true,
            false,
            () => {
              void this.handleLogout()
            }
          )
        }
        .width('100%')
        .backgroundColor(CARD_BG)
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 0, right: 0, top: 0, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(SURFACE)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Column({ space: 10 }) {
      this.buildTopBar()
      this.buildContentArea()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 0 })
    .backgroundColor(SURFACE)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}