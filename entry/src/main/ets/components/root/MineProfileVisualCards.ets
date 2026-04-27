const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#1848DE'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#11233C'
const TEXT_SUB: string = '#7C8FA6'
const DANGER: string = '#E5484D'
const WARNING: string = '#D97706'

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

        Column({ space: 6 }) {
          Text('我的')
            .fontSize(14)
            .fontColor('rgba(17,35,60,0.58)')

          Text('HearBridge')
            .fontSize(25)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
        }
        .padding({ left: 20, top: 18 })
        .alignItems(HorizontalAlign.Start)
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

            Text(`@${this.username}`)
              .fontSize(14)
              .fontColor(TEXT_SUB)

            Text(`ID ${this.userId}`)
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
      Text('资料')
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

          Text(this.avatarTip.trim().length > 0 ? this.avatarTip : '头像会上传到 MinIO，数据库只保存相对路径。')
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

/**
 * 我的页开发者模式卡。
 */
@Component
export struct MineDeveloperVisualCard {
  /** 是否启用开发者采集模式。 */
  @Prop enableDatasetCollect: boolean = false
  /** 开发者提示文案。 */
  @Prop developerTip: string = ''
  /** 切换开发者模式回调。 */
  onToggle: () => void = () => {}

  build() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 6 }) {
          Text('开发者采集模式')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F2A44')

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
            this.onToggle()
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
    .padding(18)
    .backgroundColor(CARD_BG)
    .borderRadius(28)
    .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}

/**
 * 我的页服务地址卡。
 */
@Component
export struct MineEndpointVisualCard {
  /** 后端基础地址。 */
  @Prop baseUrl: string = ''
  /** MinIO 访问地址。 */
  @Prop minioUrl: string = ''

  build() {
    Column({ space: 10 }) {
      Text('服务')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2A44')

      Text(this.baseUrl)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(TEXT_SUB)

      Text(this.minioUrl)
        .fontSize(13)
        .lineHeight(20)
        .fontColor(TEXT_SUB)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(CARD_BG)
    .borderRadius(28)
    .shadow({ radius: 18, color: '#15304B10', offsetX: 0, offsetY: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
