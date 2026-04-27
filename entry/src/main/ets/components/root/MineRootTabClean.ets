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
const TEXT_LABEL: string = '#3F5672'
const INPUT_BG: string = '#F8FBFF'
const INPUT_BORDER: string = '#C8D8EA'
const DANGER: string = '#E5484D'
const SUCCESS: string = '#2BA471'

/**
 * 我的页正式版容器。
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
  /** 当前密码。 */
  @State currentPassword: string = ''
  /** 新密码。 */
  @State nextPassword: string = ''
  /** 确认新密码。 */
  @State confirmPassword: string = ''
  /** 页面提示文案。 */
  @State pageTip: string = ''
  /** 是否正在退出登录。 */
  @State loggingOut: boolean = false
  /** 是否正在修改密码。 */
  @State changingPassword: boolean = false

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

  /** 打开修改密码页面。 */
  private openPasswordView(): void {
    this.currentView = 'password'
    this.currentPassword = ''
    this.nextPassword = ''
    this.confirmPassword = ''
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

  /** 提交修改密码。 */
  private async handleChangePassword(): Promise<void> {
    if (this.changingPassword) {
      return
    }
    if (this.currentPassword.length < 6) {
      this.pageTip = '请输入正确的当前密码。'
      return
    }
    if (this.nextPassword.length < 6) {
      this.pageTip = '新密码长度不能少于 6 位。'
      return
    }
    if (this.nextPassword !== this.confirmPassword) {
      this.pageTip = '两次输入的新密码不一致。'
      return
    }
    if (this.nextPassword === this.currentPassword) {
      this.pageTip = '新密码不能与当前密码相同。'
      return
    }

    this.changingPassword = true
    this.pageTip = '正在修改密码...'

    try {
      await AuthApi.changePassword(this.token, this.currentPassword, this.nextPassword, this.confirmPassword)
      await clearAuthState(this.getAbilityContext())
      this.currentView = 'main'
      this.currentPassword = ''
      this.nextPassword = ''
      this.confirmPassword = ''
      this.pageTip = ''
    } catch (err) {
      this.pageTip = `修改密码失败：${JSON.stringify(err)}`
    } finally {
      this.changingPassword = false
    }
  }

  /** 获取提示文案颜色。 */
  private getTipColor(): string {
    if (this.pageTip.indexOf('成功') >= 0) {
      return SUCCESS
    }
    if (this.pageTip.indexOf('正在') >= 0) {
      return TEXT_SUB
    }
    return DANGER
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

  /** 构建密码输入框。 */
  @Builder
  private buildPasswordInput(label: string, placeholder: string, value: string, onChange: (value: string) => void): void {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_LABEL)

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(52)
        .type(InputType.Password)
        .fontSize(16)
        .fontColor('#1D2F45')
        .placeholderColor('#778CA7')
        .placeholderFont({ size: 15 })
        .backgroundColor(INPUT_BG)
        .borderRadius(16)
        .border({ width: 1, color: INPUT_BORDER })
        .padding({ left: 15, right: 15 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 构建页面提示。 */
  @Builder
  private buildPageTip(): void {
    if (this.pageTip.trim().length > 0) {
      Text(this.pageTip)
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.getTipColor())
        .padding({ left: 4, right: 4 })
    }
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
          this.openPasswordView()
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

      this.buildPageTip()
    }
    .width('100%')
  }

  /** 构建修改密码页面。 */
  @Builder
  private buildPasswordContent(): void {
    Column({ space: 16 }) {
      this.buildPageHeader('修改密码', () => {
        this.openSecurityView()
      })

      Column({ space: 14 }) {
        this.buildPasswordInput('当前密码', '请输入当前密码', this.currentPassword, (value: string) => {
          this.currentPassword = value
        })
        this.buildPasswordInput('新密码', '请输入新密码', this.nextPassword, (value: string) => {
          this.nextPassword = value
        })
        this.buildPasswordInput('确认新密码', '请再次输入新密码', this.confirmPassword, (value: string) => {
          this.confirmPassword = value
        })

        this.buildPageTip()

        Button(this.changingPassword ? '提交中...' : '确认修改')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .linearGradient({
            angle: 90,
            colors: [['#5FA7FF', 0], ['#2E79F4', 1]]
          })
          .borderRadius(18)
          .enabled(!this.changingPassword)
          .onClick(() => {
            void this.handleChangePassword()
          })
      }
      .width('100%')
      .padding(18)
      .backgroundColor(CARD_BG)
      .borderRadius(28)
      .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
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
          } else if (this.currentView === 'password') {
            this.buildPasswordContent()
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
