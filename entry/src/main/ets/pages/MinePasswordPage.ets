import common from '@ohos.app.ability.common'
import { router } from '@kit.ArkUI'
import { AuthApi } from '../api/AuthApi'
import { clearAuthState } from '../common/auth/AuthStorage'

const PRIMARY: string = '#1848DE'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const SECONDARY_TEXT: string = '#6B7A90'
const DANGER: string = '#E5484D'
const BORDER: string = '#E5EAF3'
const SURFACE: string = '#FFFFFF'
const INPUT_BG: string = '#F7FAFE'
const ICON_MUTED: string = '#9AACBF'

/**
 * 我的 / 修改密码页面。
 *
 * 说明：
 * 1. 修改密码从账号与安全页拆出为独立二级页面。
 * 2. 修改成功后后端会清除当前 token。
 * 3. 前端同步清空本地登录态，并返回上一页。
 */
@Entry
@Component
struct MinePasswordPage {
  /** 当前登录 token。 */
  @StorageLink('auth.token') token: string = ''

  /** 原密码。 */
  @State oldPassword: string = ''

  /** 新密码。 */
  @State newPassword: string = ''

  /** 确认新密码。 */
  @State confirmPassword: string = ''

  /** 是否正在修改密码。 */
  @State changingPassword: boolean = false

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
      console.error(`返回账号与安全页失败：${JSON.stringify(err)}`)
    }
  }


  /**
   * 清空密码输入框。
   */
  private clearPasswordInputs(): void {
    this.oldPassword = ''
    this.newPassword = ''
    this.confirmPassword = ''
  }

  /**
   * 处理修改密码。
   */
  private async handleChangePassword(): Promise<void> {
    if (this.changingPassword) {
      return
    }

    const oldPassword = this.oldPassword.trim()
    const newPassword = this.newPassword.trim()
    const confirmPassword = this.confirmPassword.trim()

    if (this.token.trim().length === 0) {
      this.pageTip = '登录状态已失效，请重新登录。'
      return
    }

    if (oldPassword.length === 0 || newPassword.length === 0 || confirmPassword.length === 0) {
      this.pageTip = '密码输入不能为空。'
      return
    }

    if (newPassword.length < 6 || confirmPassword.length < 6) {
      this.pageTip = '新密码至少 6 位。'
      return
    }

    if (newPassword !== confirmPassword) {
      this.pageTip = '两次输入的新密码不一致。'
      return
    }

    if (oldPassword === newPassword) {
      this.pageTip = '新密码不能和原密码相同。'
      return
    }

    this.changingPassword = true
    this.pageTip = '正在修改密码...'

    try {
      await AuthApi.changePassword(this.token, oldPassword, newPassword, confirmPassword)
      this.clearPasswordInputs()
      await clearAuthState(this.getAbilityContext())
      this.pageTip = '密码已修改，请重新登录。'
      this.goBack()
    } catch (err) {
      this.pageTip = `修改密码失败：${JSON.stringify(err)}`
    } finally {
      this.changingPassword = false
    }
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

      Text('修改密码')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Blank()
    }
    .width('100%')
    .padding({ top: 2, bottom: 8 })
  }

  /**
   * 构建密码输入框。
   */
  @Builder
  private buildPasswordInput(
    label: string,
    placeholder: string,
    value: string,
    onChange: (value: string) => void
  ): void {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(48)
        .type(InputType.Password)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .placeholderColor(ICON_MUTED)
        .backgroundColor(INPUT_BG)
        .borderRadius(14)
        .border({ width: 1, color: BORDER })
        .padding({ left: 14, right: 14 })
        .onChange((inputValue: string): void => {
          onChange(inputValue)
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 构建表单区域。
   */
  @Builder
  private buildPasswordForm(): void {
    Column({ space: 16 }) {
      this.buildPasswordInput('原密码', '请输入原密码', this.oldPassword, (value: string): void => {
        this.oldPassword = value
      })

      this.buildPasswordInput('新密码', '至少 6 位', this.newPassword, (value: string): void => {
        this.newPassword = value
      })

      this.buildPasswordInput('确认新密码', '请再次输入新密码', this.confirmPassword, (value: string): void => {
        this.confirmPassword = value
      })

      Button(this.changingPassword ? '修改中...' : '保存新密码')
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY)
        .borderRadius(16)
        .enabled(!this.changingPassword)
        .onClick(() => {
          void this.handleChangePassword()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(SURFACE)
  }

  build() {
    Column({ space: 10 }) {
      this.buildTopBar()

      Scroll() {
        Column() {
          this.buildPasswordForm()
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
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 0 })
    .backgroundColor(SURFACE)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}