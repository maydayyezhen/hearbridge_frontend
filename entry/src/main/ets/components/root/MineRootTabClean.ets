import common from '@ohos.app.ability.common'
import { AuthApi } from '../../api/AuthApi'
import { clearAuthState } from '../../common/auth/AuthStorage'
import { MineMenuVisualCard, MineProfileHeaderCard } from './MineProfileVisualCards'
import { MineRootTab } from './MineRootTab'

const PAGE_BG: string = '#F8FBFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const DANGER: string = '#E5484D'

/**
 * 我的页正式版容器。
 *
 * 说明：
 * 1. 未登录场景继续复用原 MineRootTab 的登录 / 注册能力。
 * 2. 已登录场景只展示正式用户中心，不展示后端地址、MinIO 地址、开发者采集模式等调试信息。
 * 3. 账号与安全作为二级页面接入当前容器内部路由。
 */
@Component
export struct MineRootTabClean {
  /** 当前系统内可用的手势分类数量。 */
  @Prop categoryCount: number = 0
  /** 是否只显示登录页。 */
  @Prop loginOnly: boolean = false

  /** 是否已登录。 */
  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false
  /** 当前登录 token。 */
  @StorageLink('auth.token') token: string = ''
  /** 当前用户 ID。 */
  @StorageLink('auth.user.id') userId: number = 0
  /** 当前用户名。 */
  @StorageLink('auth.user.username') username: string = ''
  /** 当前用户昵称。 */
  @StorageLink('auth.user.nickname') nickname: string = ''
  /** 当前头像地址。 */
  @StorageLink('auth.user.avatarUrl') avatarUrl: string = ''
  /** 最近练习编码。 */
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''
  /** 最近练习名称。 */
  @StorageLink('recent.practice.name') recentPracticeName: string = ''

  /** 当前我的页内部视图。 */
  @State currentView: string = 'main'
  /** 页面提示文案，仅用于二级页必要操作反馈。 */
  @State pageTip: string = ''
  /** 是否正在退出登录。 */
  @State loggingOut: boolean = false

  /** 获取当前 Ability 上下文。 */
  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

  /** 获取展示名称。 */
  private getDisplayName(): string {
    if (this.nickname.trim().length > 0) {
      return this.nickname
    }
    if (this.username.trim().length > 0) {
      return this.username
    }
    return '未登录'
  }

  /** 获取头像文字兜底。 */
  private getAvatarText(): string {
    const source = this.getDisplayName()
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'H'
  }

  /** 获取最近练习标题。 */
  private getRecentPracticeTitle(): string {
    if (this.recentPracticeName.trim().length > 0) {
      return this.recentPracticeName
    }
    if (this.recentPracticeCode.trim().length > 0) {
      return this.recentPracticeCode
    }
    return '还没有开始练习'
  }

  /** 打开主页面。 */
  private openMainView(): void {
    this.currentView = 'main'
    this.pageTip = ''
  }

  /** 打开账号与安全页面。 */
  private openSecurityView(): void {
    this.currentView = 'security'
    this.pageTip = ''
  }

  /** 打开预留页面，当前不显示任何提示，避免主页面卡片出现半成品感。 */
  private openReservedView(): void {
  }

  /** 退出登录。 */
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
    this.currentView = 'main'
    this.pageTip = ''
    this.loggingOut = false
  }

  /** 构建二级页面头部。 */
  @Builder
  private buildPageHeader(title: string, onBack: () => void): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor(['#6B7A90'])
      }
      .width(40)
      .height(40)
      .borderRadius(14)
      .backgroundColor('#FFFFFF')
      .stateEffect(false)
      .onClick(() => {
        onBack()
      })

      Text(title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
    }
    .width('100%')
  }

  /** 构建账号与安全菜单行。 */
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

  /** 构建账号与安全二级页面。 */
  @Builder
  private buildSecurityContent(): void {
    Column({ space: 16 }) {
      this.buildPageHeader('账号与安全', () => {
        this.openMainView()
      })

      Column({ space: 10 }) {
        this.buildSecurityRow($r('sys.symbol.lock'), '修改密码', false, () => {
        })

        this.buildSecurityRow($r('sys.symbol.power'), this.loggingOut ? '退出中...' : '退出登录', true, () => {
          void this.handleLogout()
        })
      }
      .width('100%')
      .padding(8)
      .backgroundColor(CARD_BG)
      .borderRadius(28)
      .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })

      if (this.pageTip.trim().length > 0) {
        Text(this.pageTip)
          .width('100%')
          .fontSize(12)
          .fontColor(TEXT_SUB)
          .padding({ left: 4, right: 4 })
      }
    }
    .width('100%')
  }

  /** 构建正式我的页主内容。 */
  @Builder
  private buildMainContent(): void {
    Column({ space: 16 }) {
      MineProfileHeaderCard({
        displayName: this.getDisplayName(),
        username: this.username,
        userId: this.userId,
        avatarUrl: this.avatarUrl,
        avatarText: this.getAvatarText(),
        categoryCount: this.categoryCount,
        recentPracticeTitle: this.getRecentPracticeTitle()
      })

      MineMenuVisualCard({
        onOpenFavorites: (): void => {
          this.openReservedView()
        },
        onOpenAccountProfile: (): void => {
          this.openReservedView()
        },
        onOpenAccountSecurity: (): void => {
          this.openSecurityView()
        },
        onOpenHelpFeedback: (): void => {
          this.openReservedView()
        },
        onOpenAboutHearBridge: (): void => {
          this.openReservedView()
        }
      })
    }
    .width('100%')
  }

  build() {
    if (!this.isLoggedIn) {
      MineRootTab({
        categoryCount: this.categoryCount,
        loginOnly: this.loginOnly
      })
    } else {
      Scroll() {
        Column({ space: 16 }) {
          if (this.currentView === 'security') {
            this.buildSecurityContent()
          } else {
            this.buildMainContent()
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: this.loginOnly ? 42 : 16, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BG)
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
  }
}
