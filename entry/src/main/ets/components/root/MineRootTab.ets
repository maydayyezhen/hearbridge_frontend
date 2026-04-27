import common from '@ohos.app.ability.common'
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { AppConfig } from '../../common/constants/AppConfig'
import { AuthApi } from '../../api/AuthApi'
import { clearAuthState, saveAuthState, saveUserState } from '../../common/auth/AuthStorage'
import { readAvatarBytes, resolveAvatarFileName, resolveAvatarMimeType } from '../../common/file/AvatarFileReader'

const PAGE_BG: string = '#F5F7FB'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const DANGER: string = '#D14343'
const WARNING: string = '#D97706'

@Component
export struct MineRootTab {
  @Prop categoryCount: number = 0
  @Prop loginOnly: boolean = false

  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false
  @StorageLink('auth.token') token: string = ''
  @StorageLink('auth.user.id') userId: number = 0
  @StorageLink('auth.user.username') username: string = ''
  @StorageLink('auth.user.nickname') nickname: string = ''
  @StorageLink('auth.user.avatarUrl') avatarUrl: string = ''

  @StorageLink('recent.practice.code') recentPracticeCode: string = ''
  @StorageLink('recent.practice.name') recentPracticeName: string = ''

  @StorageLink('developer.datasetCollect.enabled') enableDatasetCollect: boolean = false

  @State authMode: string = 'login'
  @State loginUsername: string = ''
  @State loginPassword: string = ''
  @State registerUsername: string = ''
  @State registerPassword: string = ''
  @State registerNickname: string = ''
  @State editNickname: string = ''
  @State selectedAvatarUri: string = ''
  @State tipText: string = ''
  @State avatarTip: string = ''
  @State developerTip: string = ''
  @State submitting: boolean = false
  @State uploadingAvatar: boolean = false
  @State pickingAvatar: boolean = false

  aboutToAppear(): void {
    this.editNickname = this.nickname
    AppStorage.setOrCreate(AppConfig.DATASET_COLLECT_STORAGE_KEY, AppConfig.DEFAULT_ENABLE_DATASET_COLLECT)
  }

  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

  private getDisplayName(): string {
    if (this.nickname.trim().length > 0) {
      return this.nickname
    }
    if (this.username.trim().length > 0) {
      return this.username
    }
    return '未登录'
  }

  private getAvatarText(): string {
    const source = this.getDisplayName()
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'H'
  }

  private getVisibleAvatarUri(): string {
    if (this.selectedAvatarUri.trim().length > 0) {
      return this.selectedAvatarUri
    }
    return this.avatarUrl
  }

  private getRecentPracticeTitle(): string {
    if (this.recentPracticeName.trim().length > 0) {
      return this.recentPracticeName
    }
    if (this.recentPracticeCode.trim().length > 0) {
      return this.recentPracticeCode
    }
    return '还没有开始练习'
  }

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
    this.tipText = '已退出登录'
    this.submitting = false
  }

  private handleToggleDatasetCollect(): void {
    const nextValue = !this.enableDatasetCollect
    AppStorage.setOrCreate(AppConfig.DATASET_COLLECT_STORAGE_KEY, nextValue)
    this.enableDatasetCollect = nextValue
    this.developerTip = nextValue
      ? '开发者采集模式已开启，手势练习页可采集 raw dataset 样本。'
      : '开发者采集模式已关闭，普通用户不会使用 raw dataset 采集能力。'
  }

  @Builder
  private buildInput(label: string, placeholder: string, value: string, password: boolean, onChange: (value: string) => void): void {
    Column({ space: 8 }) {
      Text(label)
        .fontSize(13)
        .fontColor(TEXT_SUB)

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(46)
        .type(password ? InputType.Password : InputType.Normal)
        .fontSize(15)
        .fontColor(TEXT_MAIN)
        .placeholderColor('#A4ACB9')
        .backgroundColor('#F7F9FD')
        .borderRadius(14)
        .padding({ left: 14, right: 14 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildModeSwitch(): void {
    Row() {
      this.buildModeButton('login', '登录')
      this.buildModeButton('register', '注册')
    }
    .width('100%')
    .height(46)
    .padding(4)
    .backgroundColor('#F0F4FA')
    .borderRadius(16)
  }

  @Builder
  private buildModeButton(mode: string, label: string): void {
    Button(label)
      .layoutWeight(1)
      .height(38)
      .fontSize(15)
      .fontWeight(this.authMode === mode ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.authMode === mode ? PRIMARY : TEXT_SUB)
      .backgroundColor(this.authMode === mode ? CARD_BG : Color.Transparent)
      .borderRadius(12)
      .onClick(() => {
        this.authMode = mode
        this.tipText = ''
      })
  }

  @Builder
  private buildAuthCard(): void {
    Column({ space: 18 }) {
      Column({ space: 10 }) {
        Text('HearBridge')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Text('听桥手语学习与辅助交流系统')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY)

        Text('登录后可查看手语课程、播放数字人示范、使用实时识别与个人资料能力。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor(TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      this.buildModeSwitch()

      if (this.authMode === 'login') {
        this.buildInput('用户名', '输入用户名', this.loginUsername, false, (value: string) => {
          this.loginUsername = value.trim()
        })
        this.buildInput('密码', '输入密码', this.loginPassword, true, (value: string) => {
          this.loginPassword = value
        })

        Button(this.submitting ? '登录中...' : '登录并进入系统')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(PRIMARY)
          .borderRadius(16)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.handleLogin()
          })
      } else {
        this.buildInput('用户名', '至少 3 位', this.registerUsername, false, (value: string) => {
          this.registerUsername = value.trim()
        })
        this.buildInput('密码', '至少 6 位', this.registerPassword, true, (value: string) => {
          this.registerPassword = value
        })
        this.buildInput('昵称', '显示在我的页面', this.registerNickname, false, (value: string) => {
          this.registerNickname = value
        })

        Button(this.submitting ? '注册中...' : '创建账号并进入')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(PRIMARY)
          .borderRadius(16)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.handleRegister()
          })
      }

      if (this.tipText.trim().length > 0) {
        Text(this.tipText)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.tipText.indexOf('失败') >= 0 ? DANGER : TEXT_SUB)
      }
    }
    .width('100%')
    .padding(22)
    .backgroundColor(CARD_BG)
    .borderRadius(24)
  }

  @Builder
  private buildAvatar(size: number): void {
    Stack({ alignContent: Alignment.Center }) {
      if (this.getVisibleAvatarUri().trim().length > 0) {
        Image(this.getVisibleAvatarUri())
          .width(size)
          .height(size)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.getAvatarText())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY)
      }
    }
    .width(size)
    .height(size)
    .borderRadius(22)
    .backgroundColor(PRIMARY_SOFT)
  }

  @Builder
  private buildProfileCard(): void {
    Column({ space: 18 }) {
      Row({ space: 16 }) {
        this.buildAvatar(74)

        Column({ space: 6 }) {
          Text(this.getDisplayName())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`@${this.username}`)
            .fontSize(14)
            .fontColor(TEXT_SUB)

          Text(`ID ${this.userId}`)
            .fontSize(12)
            .fontColor('#98A2B3')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 12 }) {
        this.buildMiniStatus('分类', `${this.categoryCount}`)
        this.buildMiniStatus('最近', this.getRecentPracticeTitle())
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(22)
  }

  @Builder
  private buildMiniStatus(label: string, value: string): void {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor(TEXT_SUB)

      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding(14)
    .backgroundColor('#F7F9FD')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildEditCard(): void {
    Column({ space: 16 }) {
      Text('资料')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Row({ space: 14 }) {
        this.buildAvatar(66)

        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Button(this.pickingAvatar ? '选择中...' : '选择图片')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor(PRIMARY)
              .backgroundColor(PRIMARY_SOFT)
              .borderRadius(14)
              .enabled(!this.pickingAvatar && !this.uploadingAvatar)
              .onClick(() => {
                void this.handlePickAvatar()
              })

            Button(this.uploadingAvatar ? '上传中...' : '上传头像')
              .layoutWeight(1)
              .height(40)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor(PRIMARY)
              .borderRadius(14)
              .enabled(!this.uploadingAvatar && this.selectedAvatarUri.trim().length > 0)
              .onClick(() => {
                void this.handleUploadAvatar()
              })
          }
          .width('100%')

          Text(this.avatarTip.trim().length > 0 ? this.avatarTip : '头像会上传到 MinIO，数据库只保存相对路径。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(this.avatarTip.indexOf('失败') >= 0 ? DANGER : TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      this.buildInput('昵称', '输入昵称', this.editNickname, false, (value: string) => {
        this.editNickname = value
      })

      Row({ space: 12 }) {
        Button(this.submitting ? '保存中...' : '保存资料')
          .layoutWeight(1)
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(PRIMARY)
          .borderRadius(16)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.handleUpdateProfile()
          })

        Button('退出')
          .width(92)
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(DANGER)
          .backgroundColor('#FFF1F1')
          .borderRadius(16)
          .enabled(!this.submitting)
          .onClick(() => {
            void this.handleLogout()
          })
      }
      .width('100%')

      if (this.tipText.trim().length > 0) {
        Text(this.tipText)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor(this.tipText.indexOf('失败') >= 0 ? DANGER : TEXT_SUB)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(22)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildDeveloperCard(): void {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text('开发者采集模式')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)

          Text('开启后，手势练习页可采集 raw dataset 样本，用于管理端同步、特征转换和模型训练。')
            .fontSize(13)
            .lineHeight(20)
            .fontColor(TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.enableDatasetCollect ? '已开启' : '已关闭')
          .width(90)
          .height(38)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.enableDatasetCollect ? '#FFFFFF' : WARNING)
          .backgroundColor(this.enableDatasetCollect ? WARNING : '#FFF7ED')
          .borderRadius(14)
          .onClick(() => {
            this.handleToggleDatasetCollect()
          })
      }
      .width('100%')

      Text(this.enableDatasetCollect ? '当前会显示 raw 样本采集入口，请仅在管理员采集数据时使用。' : '普通用户模式下不会连接 Python raw dataset 采集服务。')
        .fontSize(12)
        .lineHeight(18)
        .fontColor(this.enableDatasetCollect ? WARNING : TEXT_SUB)

      if (this.developerTip.trim().length > 0) {
        Text(this.developerTip)
          .fontSize(12)
          .lineHeight(18)
          .fontColor(TEXT_SUB)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(22)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildEndpointCard(): void {
    Column({ space: 10 }) {
      Text('服务')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Text(AppConfig.BASE_URL)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(TEXT_SUB)

      Text(AppConfig.buildMinioBucketBaseUrl())
        .fontSize(13)
        .lineHeight(20)
        .fontColor(TEXT_SUB)
    }
    .width('100%')
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(22)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        if (this.isLoggedIn) {
          this.buildProfileCard()
          this.buildEditCard()
          if (!this.loginOnly) {
            this.buildDeveloperCard()
          }
        } else {
          this.buildAuthCard()
        }

        if (!this.loginOnly || !this.isLoggedIn) {
          this.buildEndpointCard()
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
