import common from '@ohos.app.ability.common'
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { AuthApi } from '../../api/AuthApi'
import { clearAuthState, saveAuthState, saveUserState } from '../../common/auth/AuthStorage'
import { readAvatarBytes, resolveAvatarFileName, resolveAvatarMimeType } from '../../common/file/AvatarFileReader'
import { MineMenuVisualCard, MineProfileEditVisualCard, MineProfileHeaderCard } from './MineProfileVisualCards'

const PAGE_BG: string = '#F8FBFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const PRIMARY_LIGHT: string = '#3AAAE8'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const TEXT_LABEL: string = '#3F5672'
const INPUT_BG: string = '#F8FBFF'
const INPUT_BORDER: string = '#C8D8EA'
const DANGER: string = '#E5484D'
const SUCCESS: string = '#2BA471'

@Component
export struct MineRootTab {
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

  /** 当前认证模式：login / register。 */
  @State authMode: string = 'login'
  /** 当前我的页子视图：main / accountProfile。 */
  @State currentMineView: string = 'main'
  /** 登录账号。 */
  @State loginUsername: string = ''
  /** 登录密码。 */
  @State loginPassword: string = ''
  /** 注册账号。 */
  @State registerUsername: string = ''
  /** 注册密码。 */
  @State registerPassword: string = ''
  /** 注册昵称。 */
  @State registerNickname: string = ''
  /** 编辑中的昵称。 */
  @State editNickname: string = ''
  /** 已选择但尚未上传的头像 URI。 */
  @State selectedAvatarUri: string = ''
  /** 通用提示文案。 */
  @State tipText: string = ''
  /** 头像提示文案。 */
  @State avatarTip: string = ''
  /** 是否正在提交。 */
  @State submitting: boolean = false
  /** 是否正在上传头像。 */
  @State uploadingAvatar: boolean = false
  /** 是否正在选择头像。 */
  @State pickingAvatar: boolean = false

  aboutToAppear(): void {
    this.editNickname = this.nickname
  }

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

  /** 获取当前实际展示的头像地址。 */
  private getVisibleAvatarUri(): string {
    if (this.selectedAvatarUri.trim().length > 0) {
      return this.selectedAvatarUri
    }
    return this.avatarUrl
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

  /** 打开暂未接入的二级页面提示。 */
  private openPendingRoute(routeName: string): void {
    this.currentMineView = 'main'
    this.tipText = `${routeName} 页面下一步接入。`
  }

  /** 打开账号资料页。 */
  private openAccountProfileView(): void {
    this.currentMineView = 'accountProfile'
    this.tipText = ''
    this.avatarTip = ''
    this.editNickname = this.nickname
  }

  /** 返回我的页主视图。 */
  private backToMineMain(): void {
    this.currentMineView = 'main'
  }

  /** 处理账号密码登录。 */
  private async handleLogin(): Promise<void> {
    if (this.submitting) {
      return
    }

    const username = this.loginUsername.trim()
    const password = this.loginPassword.trim()

    if (username.length < 3 || password.length < 6) {
      this.tipText = '请输入正确的用户名和密码'
      return
    }

    this.submitting = true
    this.tipText = '正在登录...'

    try {
      const result = await AuthApi.login(username, password)
      await saveAuthState(this.getAbilityContext(), result.token, result.user)
      this.loginPassword = ''
      this.editNickname = result.user.nickname
      this.selectedAvatarUri = ''
      this.tipText = '登录成功'
    } catch (err) {
      this.tipText = `登录失败：${JSON.stringify(err)}`
    } finally {
      this.submitting = false
    }
  }

  /** 处理注册账号。 */
  private async handleRegister(): Promise<void> {
    if (this.submitting) {
      return
    }

    const username = this.registerUsername.trim()
    const password = this.registerPassword.trim()
    const nickname = this.registerNickname.trim()

    if (username.length < 3 || password.length < 6) {
      this.tipText = '用户名至少 3 位，密码至少 6 位'
      return
    }

    if (nickname.length === 0) {
      this.tipText = '给自己起一个昵称吧'
      return
    }

    this.submitting = true
    this.tipText = '正在注册...'

    try {
      const result = await AuthApi.register(username, password, nickname)
      await saveAuthState(this.getAbilityContext(), result.token, result.user)
      this.registerPassword = ''
      this.editNickname = result.user.nickname
      this.selectedAvatarUri = ''
      this.tipText = '注册成功'
    } catch (err) {
      this.tipText = `注册失败：${JSON.stringify(err)}`
    } finally {
      this.submitting = false
    }
  }

  /** 保存用户昵称资料。 */
  private async handleUpdateProfile(): Promise<void> {
    if (this.submitting) {
      return
    }

    const nickname = this.editNickname.trim()

    if (nickname.length === 0) {
      this.tipText = '昵称不能为空'
      return
    }

    this.submitting = true
    this.tipText = '正在保存资料...'

    try {
      const user = await AuthApi.updateProfile(this.token, nickname)
      await saveUserState(this.getAbilityContext(), user)
      this.editNickname = user.nickname
      this.tipText = '资料已更新'
    } catch (err) {
      this.tipText = `保存失败：${JSON.stringify(err)}`
    } finally {
      this.submitting = false
    }
  }

  /** 从系统相册选择头像。 */
  private async handlePickAvatar(): Promise<void> {
    if (this.pickingAvatar || this.uploadingAvatar) {
      return
    }

    this.pickingAvatar = true
    this.avatarTip = '正在打开相册...'

    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker()
      let pickerOptions = new photoAccessHelper.PhotoSelectOptions()
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      pickerOptions.maxSelectNumber = 1

      const pickerResult = await photoPicker.select(pickerOptions)

      if (pickerResult.photoUris.length > 0) {
        this.selectedAvatarUri = pickerResult.photoUris[0].split('#')[0].split('?')[0]
        this.avatarTip = '已选择图片，点击上传即可保存头像'
      } else {
        this.avatarTip = '没有选择图片'
      }
    } catch (_err) {
      this.avatarTip = '当前环境不支持相册读取，请在真机重试'
    } finally {
      this.pickingAvatar = false
    }
  }

  /** 上传头像并刷新本地用户状态。 */
  private async handleUploadAvatar(): Promise<void> {
    if (this.uploadingAvatar || this.selectedAvatarUri.trim().length === 0) {
      if (this.selectedAvatarUri.trim().length === 0) {
        this.avatarTip = '请先选择一张头像图片'
      }
      return
    }

    if (this.token.trim().length === 0) {
      this.avatarTip = '登录状态已失效，请重新登录'
      return
    }

    this.uploadingAvatar = true
    this.avatarTip = '正在上传头像...'

    try {
      const fileName = resolveAvatarFileName(this.selectedAvatarUri)
      const mimeType = resolveAvatarMimeType(fileName)
      const bytes = await readAvatarBytes(this.getAbilityContext() as common.UIAbilityContext, this.selectedAvatarUri)

      if (bytes.byteLength <= 0) {
        this.avatarTip = '图片读取失败，请重新选择'
        return
      }

      const user = await AuthApi.uploadAvatar(this.token, fileName, mimeType, bytes)
      await saveUserState(this.getAbilityContext(), user)
      this.selectedAvatarUri = ''
      this.avatarTip = '头像已上传'
    } catch (err) {
      this.avatarTip = `头像上传失败：${JSON.stringify(err)}`
    } finally {
      this.uploadingAvatar = false
    }
  }

  /** 退出登录。 */
  private async handleLogout(): Promise<void> {
    if (this.submitting) {
      return
    }

    this.submitting = true

    try {
      await AuthApi.logout(this.token)
    } catch (_err) {
    }

    await clearAuthState(this.getAbilityContext())
    this.selectedAvatarUri = ''
    this.currentMineView = 'main'
    this.tipText = '已退出登录'
    this.submitting = false
  }

  /** 获取默认认证提示。 */
  private getDefaultAuthTip(): string {
    return this.authMode === 'login'
      ? '欢迎回来，输入账号和密码继续训练。'
      : '创建账号后就可以开始课程与训练。'
  }

  /** 是否展示认证提示。 */
  private shouldShowAuthTip(): boolean {
    return this.tipText.trim().length > 0 && this.tipText !== this.getDefaultAuthTip()
  }

  /** 获取提示文案颜色。 */
  private getTipColor(): string {
    if (this.tipText.indexOf('成功') >= 0) {
      return SUCCESS
    }

    if (
      this.tipText.indexOf('正在') >= 0 ||
        this.tipText.indexOf('已') === 0 ||
        this.tipText.indexOf('下一步') >= 0
    ) {
      return TEXT_SUB
    }

    return DANGER
  }

  /** 构建输入框。 */
  @Builder
  private buildInput(
    label: string,
    placeholder: string,
    value: string,
    password: boolean,
    onChange: (value: string) => void
  ): void {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_LABEL)

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(52)
        .type(password ? InputType.Password : InputType.Normal)
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

  /** 构建认证提示。 */
  @Builder
  private buildAuthTip(): void {
    if (this.shouldShowAuthTip()) {
      Text(this.tipText)
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.getTipColor())
        .textAlign(TextAlign.Start)
        .margin({ top: -4 })
    }
  }

  /** 构建密码登录表单。 */
  @Builder
  private buildPasswordLoginForm(): void {
    Column({ space: 18 }) {
      Text('账号密码登录')
        .width('100%')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .textAlign(TextAlign.Center)

      Column({ space: 14 }) {
        this.buildInput('账号', '请输入账号', this.loginUsername, false, (value: string) => {
          this.loginUsername = value.trim()
        })

        this.buildInput('密码', '请输入密码', this.loginPassword, true, (value: string) => {
          this.loginPassword = value
        })
      }
      .width('100%')

      this.buildAuthTip()

      Button(this.submitting ? '登录中...' : '立即登录')
        .width('100%')
        .height(54)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .linearGradient({
          angle: 105,
          colors: this.submitting
            ? [['#90B0D8', 0], ['#6E8EB8', 1]]
            : [[PRIMARY_LIGHT, 0], [PRIMARY, 1]]
        })
        .borderRadius(18)
        .shadow({ radius: 22, color: '#2A1848DE', offsetX: 0, offsetY: 10 })
        .enabled(!this.submitting)
        .onClick(() => {
          void this.handleLogin()
        })

      Row() {
        Button('短信验证码登录')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5A8BEA')
          .backgroundColor(Color.Transparent)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .stateEffect(false)
          .onClick(() => {
            this.tipText = '当前版本暂未接入短信验证码登录'
          })

        Button('没有账号？')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5A8BEA')
          .backgroundColor(Color.Transparent)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .stateEffect(false)
          .onClick(() => {
            this.authMode = 'register'
            this.tipText = ''
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: -10 })
    }
    .width('100%')
  }

  /** 构建注册表单。 */
  @Builder
  private buildRegisterForm(): void {
    Column() {
      Column({ space: 18 }) {
        Stack() {
          Text('创建听桥账号')
            .width('100%')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .textAlign(TextAlign.Center)

          Row() {
            Button() {
              SymbolGlyph($r('sys.symbol.chevron_backward'))
                .fontSize(21)
                .fontColor(['#7E8794'])
            }
            .width(36)
            .height(36)
            .backgroundColor(Color.Transparent)
            .borderRadius(10)
            .stateEffect(false)
            .onClick(() => {
              this.authMode = 'login'
              this.tipText = ''
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Start)
          .position({ x: -12, y: 0 })
        }
        .width('100%')
        .height(32)

        Column({ space: 14 }) {
          this.buildInput('注册账号', '请输入账号', this.registerUsername, false, (value: string) => {
            this.registerUsername = value.trim()
          })

          this.buildInput('设置密码', '至少 6 位', this.registerPassword, true, (value: string) => {
            this.registerPassword = value
          })

          this.buildInput('昵称', '显示在我的页面', this.registerNickname, false, (value: string) => {
            this.registerNickname = value
          })
        }
        .width('100%')

        this.buildAuthTip()

        Button(this.submitting ? '注册中...' : '注册账号')
          .width('100%')
          .height(54)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .linearGradient({
            angle: 105,
            colors: this.submitting
              ? [['#90B0D8', 0], ['#6E8EB8', 1]]
              : [[PRIMARY_LIGHT, 0], [PRIMARY, 1]]
          })
          .borderRadius(18)
          .shadow({ radius: 22, color: '#2A1848DE', offsetX: 0, offsetY: 10 })
          .enabled(!this.submitting)
          .onClick(() => {
            void this.handleRegister()
          })
      }
      .width('100%')
      .padding({ left: 0, right: 0, top: 0, bottom: 16 })
    }
    .width('100%')
  }

  /** 构建认证卡片。 */
  @Builder
  private buildAuthCard(): void {
    Column() {
      if (this.authMode === 'login') {
        this.buildPasswordLoginForm()
      } else {
        this.buildRegisterForm()
      }
    }
    .width('100%')
  }

  /** 构建认证底部协议提示。 */
  @Builder
  private buildAuthFooterText(): void {
    if (this.authMode === 'login') {
      Text('登录即代表同意《用户协议》与《隐私条款》')
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .textAlign(TextAlign.Center)
        .fontColor(TEXT_SUB)
    }
  }

  /** 构建独立登录页脚手架。 */
  @Builder
  private buildAuthScaffold(): void {
    Stack() {
      Row()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 180,
          colors: [['#F8FBFF', 0], ['#F2F7FF', 0.42], ['#FFFFFF', 1]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      if (this.authMode === 'register') {
        Scroll() {
          Column({ space: 0 }) {
            this.buildAuthCard()
          }
          .width('100%')
          .padding({ left: 22, right: 22, top: 28, bottom: 28 })
          .constraintSize({ minHeight: '100%' })
          .alignItems(HorizontalAlign.Start)
          .justifyContent(FlexAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      } else {
        Column() {
          Column() {
            this.buildAuthCard()
          }
          .width('100%')

          Blank()
            .layoutWeight(1)

          this.buildAuthFooterText()
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 22, right: 22, top: 28, bottom: 18 })
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /** 构建二级页面头部。 */
  @Builder
  private buildPageHeader(title: string, subtitle: string, onBack: () => void): void {
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

      Column({ space: 4 }) {
        Text(title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Text(subtitle)
          .fontSize(12)
          .fontColor(TEXT_SUB)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 2, right: 2, top: 2, bottom: 2 })
  }

  /** 构建我的页主视图提示。 */
  @Builder
  private buildMineTip(): void {
    if (this.tipText.trim().length > 0) {
      Text(this.tipText)
        .width('100%')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.getTipColor())
        .padding({ left: 4, right: 4 })
    }
  }

  /** 构建我的页主内容。 */
  @Builder
  private buildMineMainContent(): void {
    Column({ space: 16 }) {
      MineProfileHeaderCard({
        displayName: this.getDisplayName(),
        username: this.username,
        userId: this.userId,
        avatarUrl: this.getVisibleAvatarUri(),
        avatarText: this.getAvatarText(),
        categoryCount: this.categoryCount,
        recentPracticeTitle: this.getRecentPracticeTitle()
      })

      MineMenuVisualCard({
        onOpenFavorites: (): void => {
          this.openPendingRoute('我的收藏')
        },
        onOpenAccountProfile: (): void => {
          this.openAccountProfileView()
        },
        onOpenAccountSecurity: (): void => {
          this.openPendingRoute('账号与安全')
        },
        onOpenHelpFeedback: (): void => {
          this.openPendingRoute('帮助与反馈')
        },
        onOpenAboutHearBridge: (): void => {
          this.openPendingRoute('关于听桥')
        }
      })

      this.buildMineTip()
    }
    .width('100%')
  }

  /** 构建账号资料内容。 */
  @Builder
  private buildAccountProfileContent(): void {
    Column({ space: 16 }) {
      this.buildPageHeader('账号资料', '修改头像、昵称与个人资料', () => {
        this.backToMineMain()
      })

      MineProfileEditVisualCard({
        avatarUrl: this.getVisibleAvatarUri(),
        avatarText: this.getAvatarText(),
        avatarTip: this.avatarTip,
        editNickname: this.editNickname,
        tipText: this.tipText,
        pickingAvatar: this.pickingAvatar,
        uploadingAvatar: this.uploadingAvatar,
        submitting: this.submitting,
        hasSelectedAvatar: this.selectedAvatarUri.trim().length > 0,
        onNicknameChange: (value: string): void => {
          this.editNickname = value
        },
        onPickAvatar: (): void => {
          void this.handlePickAvatar()
        },
        onUploadAvatar: (): void => {
          void this.handleUploadAvatar()
        },
        onSaveProfile: (): void => {
          void this.handleUpdateProfile()
        },
        onLogout: (): void => {
          void this.handleLogout()
        }
      })
    }
    .width('100%')
  }

  build() {
    if (!this.isLoggedIn && this.loginOnly) {
      this.buildAuthScaffold()
    } else {
      Scroll() {
        Column({ space: 16 }) {
          if (this.isLoggedIn) {
            if (this.currentMineView === 'accountProfile') {
              this.buildAccountProfileContent()
            } else {
              this.buildMineMainContent()
            }
          } else {
            Column() {
              this.buildAuthCard()
            }
            .width('100%')
            .padding(20)
            .backgroundColor(CARD_BG)
            .borderRadius(28)
            .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
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