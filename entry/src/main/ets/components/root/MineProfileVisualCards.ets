import { router } from '@kit.ArkUI'

const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const DANGER: string = '#E5484D'
const BORDER: string = '#E5EAF3'
const ICON_MUTED: string = '#9AACBF'


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

  /** 最近练习是否可点击。 */
  @Prop recentPracticeEnabled: boolean = false

  /** 打开最近练习回调。 */
  onOpenRecentPractice: () => void = () => {}

  /**
   * 构建普通信息行。
   */
  @Builder
  private buildInfoRow(label: string, value: string, clickable: boolean, onClickAction: () => void): void {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(label)
            .fontSize(13)
            .fontColor(TEXT_SUB)

          Text(value)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(clickable ? PRIMARY : TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (clickable) {
          SymbolGlyph($r('sys.symbol.chevron_forward'))
            .fontSize(14)
            .fontColor(['#95A7C0'])
        }
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .onClick(() => {
        if (clickable) {
          onClickAction()
        }
      })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(BORDER)
    }
    .width('100%')
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        MineAvatarView({
          avatarUrl: this.avatarUrl,
          avatarText: this.avatarText,
          avatarSize: 64
        })

        Column({ space: 5 }) {
          Text(this.displayName)
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.username.trim().length > 0 ? `@${this.username}` : '欢迎使用听桥')
            .fontSize(14)
            .fontColor(TEXT_SUB)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.userId > 0 ? `ID ${this.userId}` : '未登录用户')
            .fontSize(12)
            .fontColor('#9AA8BA')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ top: 4, bottom: 18 })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(BORDER)

      this.buildInfoRow(
        '最近练习',
        this.recentPracticeTitle,
        this.recentPracticeEnabled,
        () => {
          this.onOpenRecentPractice()
        }
      )
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }
}

/**
 * 我的页菜单卡片。
 */
@Component
export struct MineMenuVisualCard {
  /** 打开收藏页回调，当前正式页不展示。 */
  onOpenFavorites: () => void = () => {}

  /** 打开账号资料回调。 */
  onOpenAccountProfile: () => void = () => {}

  /** 打开账号安全回调。 */
  onOpenAccountSecurity: () => void = () => {}

  /** 打开帮助反馈回调，当前正式页不展示。 */
  onOpenHelpFeedback: () => void = () => {}

  /** 打开关于听桥回调，当前正式页不展示。 */
  onOpenAboutHearBridge: () => void = () => {}

  private pushPage(url: string): void {
    router.pushUrl({
      url: url
    }).catch((err: Object) => {
      console.error(`跳转页面失败：${JSON.stringify(err)}`)
    })
  }

  @Builder
  private buildMenuRow(icon: Resource, title: string, onClickAction: () => void, showDivider: boolean): void {
    Column() {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph(icon)
            .fontSize(18)
            .fontColor([PRIMARY])
        }
        .width(40)
        .height(40)
        .borderRadius(14)
        .backgroundColor(PRIMARY_SOFT)

        Text(title)
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)

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
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(BORDER)
          .margin({ left: 54 })
      }
    }
    .width('100%')
    .backgroundColor(CARD_BG)
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('账号设置')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      this.buildMenuRow(
        $r('sys.symbol.person'),
        '账号资料',
        () => {
          this.pushPage('pages/MineProfilePage')
          this.onOpenAccountProfile()
        },
        true
      )

      this.buildMenuRow(
        $r('sys.symbol.lock'),
        '账号与安全',
        () => {
          this.pushPage('pages/MineSecurityPage')
          this.onOpenAccountSecurity()
        },
        false
      )
    }
    .width('100%')
    .backgroundColor(CARD_BG)
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

  /** 退出登录回调：当前线性账号资料页不展示退出入口。 */
  onLogout: () => void = () => {}

  /**
   * 判断提示是否为错误状态。
   */
  private isErrorTip(text: string): boolean {
    return text.indexOf('失败') >= 0 ||
      text.indexOf('失效') >= 0 ||
      text.indexOf('不能为空') >= 0 ||
      text.indexOf('请先') >= 0 ||
      text.indexOf('不支持') >= 0
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
   * 构建头像设置区域。
   */
  @Builder
  private buildAvatarSection(): void {
    Column({ space: 0 }) {
      Row({ space: 14 }) {
        MineAvatarView({
          avatarUrl: this.avatarUrl,
          avatarText: this.avatarText,
          avatarSize: 64
        })

        Text('头像')
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
      }
      .width('100%')
      .padding({ top: 12, bottom: 14 })
      .alignItems(VerticalAlign.Center)

      Row({ space: 10 }) {
        Button(this.pickingAvatar ? '读取中...' : '从相册选择')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY)
          .backgroundColor('#F7FAFE')
          .borderRadius(14)
          .border({ width: 1, color: BORDER })
          .enabled(!this.pickingAvatar && !this.uploadingAvatar)
          .onClick(() => {
            this.onPickAvatar()
          })

        Button(this.uploadingAvatar ? '上传中...' : '上传头像')
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasSelectedAvatar ? PRIMARY : ICON_MUTED)
          .backgroundColor('#F7FAFE')
          .borderRadius(14)
          .border({ width: 1, color: BORDER })
          .enabled(!this.uploadingAvatar && this.hasSelectedAvatar)
          .onClick(() => {
            this.onUploadAvatar()
          })
      }
      .width('100%')
      .padding({ bottom: 14 })

      this.buildDivider()
    }
    .width('100%')
  }

  /**
   * 构建昵称编辑区域。
   */
  @Builder
  private buildNicknameSection(): void {
    Column({ space: 10 }) {
      Text('昵称')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)

      TextInput({ text: this.editNickname, placeholder: '请输入昵称' })
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontColor(TEXT_MAIN)
        .placeholderColor(ICON_MUTED)
        .backgroundColor('#F7FAFE')
        .borderRadius(14)
        .border({ width: 1, color: BORDER })
        .padding({ left: 14, right: 14 })
        .onChange((value: string): void => {
          this.onNicknameChange(value)
        })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 构建保存按钮区域。
   */
  @Builder
  private buildSaveSection(): void {
    Column({ space: 0 }) {
      Button(this.submitting ? '保存中...' : '保存资料')
        .width('100%')
        .height(48)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY)
        .borderRadius(16)
        .enabled(!this.submitting)
        .onClick(() => {
          this.onSaveProfile()
        })
    }
    .width('100%')
    .padding({ top: 2, bottom: 8 })
  }

  build() {
    Column({ space: 0 }) {
      this.buildAvatarSection()
      this.buildNicknameSection()
      this.buildSaveSection()
    }
    .width('100%')
    .backgroundColor(CARD_BG)
    .alignItems(HorizontalAlign.Start)
  }
}
