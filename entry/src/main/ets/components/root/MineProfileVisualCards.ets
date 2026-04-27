import { router } from '@kit.ArkUI'

const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const DANGER: string = '#E5484D'

/**
 * 我的页头像展示组件。
 */
@Component
export struct MineAvatarView {
  /** 头像地址。 */
  @Prop avatarUrl: string = ''
  /** 头像文字兜底。 */
  @Prop avatarText: string = 'H'
  /** 头像尺寸，不能命名为 size，避免与 ArkUI 组件基类方法冲突。 */
  @Prop avatarSize: number = 72

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.avatarUrl.trim().length > 0) {
        Image(this.avatarUrl)
          .width(this.avatarSize)
          .height(this.avatarSize)
          .borderRadius(this.avatarSize / 2)
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.avatarText)
          .fontSize(this.avatarSize >= 70 ? 30 : 24)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.avatarSize / 2)
    .backgroundColor(PRIMARY_SOFT)
  }
}

/**
 * 我的页顶部个人资料卡。
 */
@Component
export struct MineProfileHeaderCard {
  /** 显示名称。 */
  @Prop displayName: string = ''
  /** 用户名。 */
  @Prop username: string = ''
  /** 用户 ID。 */
  @Prop userId: number = 0
  /** 头像地址。 */
  @Prop avatarUrl: string = ''
  /** 头像兜底文字。 */
  @Prop avatarText: string = 'H'
  /** 分类数量。 */
  @Prop categoryCount: number = 0
  /** 最近练习标题。 */
  @Prop recentPracticeTitle: string = ''

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
    .backgroundColor('#F7FAFE')
    .borderRadius(16)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 0 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(136)
          .linearGradient({
            angle: 135,
            colors: [['#D9ECFF', 0], ['#BBD9FF', 0.52], ['#F7FBFF', 1]]
          })
          .borderRadius(28)
      }
      .width('100%')
      .height(136)

      Column({ space: 14 }) {
        Row({ space: 14 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(82)
              .height(82)
              .borderRadius(41)
              .backgroundColor('#FFFFFF')

            MineAvatarView({
              avatarUrl: this.avatarUrl,
              avatarText: this.avatarText,
              avatarSize: 72
            })
          }
          .width(82)
          .height(82)
          .margin({ top: -42 })

          Column({ space: 6 }) {
            Text(this.displayName)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(TEXT_MAIN)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(this.username.trim().length > 0 ? `@${this.username}` : '欢迎使用听桥')
              .fontSize(14)
              .fontColor(TEXT_SUB)

            Text(this.userId > 0 ? `ID ${this.userId}` : '还没有登录用户编号')
              .fontSize(12)
              .fontColor('#9AA8BA')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ top: -22 })
        }
        .width('100%')

        Row({ space: 10 }) {
          this.buildMiniStatus('分类', `${this.categoryCount}`)
          this.buildMiniStatus('最近练习', this.recentPracticeTitle)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 18 })
      .backgroundColor(CARD_BG)
      .borderRadius(28)
    }
    .width('100%')
    .backgroundColor(CARD_BG)
    .borderRadius(28)
    .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
  }
}

/**
 * 我的页菜单卡片。
 */
@Component
export struct MineMenuVisualCard {
  /** 打开收藏页回调。 */
  onOpenFavorites: () => void = () => {}
  /** 打开账号资料回调。 */
  onOpenAccountProfile: () => void = () => {}
  /** 打开账号安全回调。 */
  onOpenAccountSecurity: () => void = () => {}
  /** 打开帮助反馈回调。 */
  onOpenHelpFeedback: () => void = () => {}
  /** 打开关于听桥回调。 */
  onOpenAboutHearBridge: () => void = () => {}

  private pushPage(url: string): void {
    router.pushUrl({
      url: url
    }).catch((err: Object) => {
      console.error(`跳转页面失败：${JSON.stringify(err)}`)
    })
  }

  @Builder
  private buildMenuRow(icon: Resource, title: string, onClickAction: () => void): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(34)
          .height(34)
          .borderRadius(17)
          .backgroundColor(PRIMARY_SOFT)

        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([PRIMARY])
      }
      .width(34)
      .height(34)

      Text(title)
        .layoutWeight(1)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)

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

  build() {
    Column({ space: 10 }) {
      this.buildMenuRow($r('sys.symbol.star'), '我的收藏', this.onOpenFavorites)
      this.buildMenuRow($r('sys.symbol.person'), '账号资料', () => {
        this.pushPage('pages/MineProfilePage')
        this.onOpenAccountProfile()
      })
      this.buildMenuRow($r('sys.symbol.lock'), '账号与安全', () => {
        this.pushPage('pages/MineSecurityPage')
        this.onOpenAccountSecurity()
      })
      this.buildMenuRow($r('sys.symbol.questionmark_circle'), '帮助与反馈', this.onOpenHelpFeedback)
      this.buildMenuRow($r('sys.symbol.info_circle'), '关于听桥', this.onOpenAboutHearBridge)
    }
    .width('100%')
    .padding(8)
    .backgroundColor(CARD_BG)
    .borderRadius(28)
    .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
  }
}

/**
 * 我的页资料编辑卡。
 */
@Component
export struct MineProfileEditVisualCard {
  /** 头像地址。 */
  @Prop avatarUrl: string = ''
  /** 头像兜底文字。 */
  @Prop avatarText: string = 'H'
  /** 头像提示文案。 */
  @Prop avatarTip: string = ''
  /** 昵称输入值。 */
  @Prop editNickname: string = ''
  /** 页面提示文案。 */
  @Prop tipText: string = ''
  /** 是否正在选择头像。 */
  @Prop pickingAvatar: boolean = false
  /** 是否正在上传头像。 */
  @Prop uploadingAvatar: boolean = false
  /** 是否正在提交。 */
  @Prop submitting: boolean = false
  /** 是否已经选择头像。 */
  @Prop hasSelectedAvatar: boolean = false

  /** 昵称变化回调。 */
  onNicknameChange: (value: string) => void = () => {}
  /** 选择头像回调。 */
  onPickAvatar: () => void = () => {}
  /** 上传头像回调。 */
  onUploadAvatar: () => void = () => {}
  /** 保存资料回调。 */
  onSaveProfile: () => void = () => {}
  /** 退出登录回调。 */
  onLogout: () => void = () => {}

  @Builder
  private buildInput(label: string, placeholder: string, value: string, onChange: (value: string) => void): void {
    Column({ space: 7 }) {
      Text(label)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3F5672')

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(52)
        .fontSize(16)
        .fontColor('#1D2F45')
        .placeholderColor('#778CA7')
        .placeholderFont({ size: 15 })
        .backgroundColor('#F8FBFF')
        .borderRadius(16)
        .border({ width: 1, color: '#C8D8EA' })
        .padding({ left: 15, right: 15 })
        .onChange(onChange)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 16 }) {
      Text('账号资料')
        .width('100%')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2A44')

      Row({ space: 14 }) {
        MineAvatarView({
          avatarUrl: this.avatarUrl,
          avatarText: this.avatarText,
          avatarSize: 72
        })

        Column({ space: 8 }) {
          Text('当前头像')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A44')

          Text(this.avatarTip.trim().length > 0 ? this.avatarTip : '可以从相册选择新头像。')
            .fontSize(12)
            .lineHeight(18)
            .fontColor(this.avatarTip.indexOf('失败') >= 0 ? DANGER : TEXT_SUB)
            .maxLines(2)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Row({ space: 10 }) {
        Button(this.pickingAvatar ? '读取中...' : '从相册选择')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor('#2E79F4')
          .backgroundColor('#F5F8FD')
          .borderRadius(16)
          .enabled(!this.pickingAvatar && !this.uploadingAvatar)
          .onClick(() => {
            this.onPickAvatar()
          })

        Button(this.uploadingAvatar ? '上传中...' : '上传头像')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontColor('#2E79F4')
          .backgroundColor('#EEF5FF')
          .borderRadius(16)
          .enabled(!this.uploadingAvatar && this.hasSelectedAvatar)
          .onClick(() => {
            this.onUploadAvatar()
          })
      }
      .width('100%')

      this.buildInput('昵称', '请输入昵称', this.editNickname, (value: string): void => {
        this.onNicknameChange(value)
      })

      if (this.tipText.trim().length > 0) {
        Text(this.tipText)
          .width('100%')
          .fontSize(12)
          .lineHeight(18)
          .fontColor(this.tipText.indexOf('失败') >= 0 ? DANGER : TEXT_SUB)
      }

      Row({ space: 12 }) {
        Button(this.submitting ? '保存中...' : '保存资料')
          .layoutWeight(1)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .linearGradient({
            angle: 90,
            colors: [['#5FA7FF', 0], ['#2E79F4', 1]]
          })
          .borderRadius(18)
          .enabled(!this.submitting)
          .onClick(() => {
            this.onSaveProfile()
          })

        Button('退出')
          .width(92)
          .height(46)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(DANGER)
          .backgroundColor('#FFF1F1')
          .borderRadius(18)
          .enabled(!this.submitting)
          .onClick(() => {
            this.onLogout()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .backgroundColor(CARD_BG)
    .borderRadius(28)
    .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
