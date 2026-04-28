import { router } from '@kit.ArkUI'
import { MineMenuVisualCard, MineProfileHeaderCard } from './MineProfileVisualCards'
import { MineRootTab } from './MineRootTab'
import { GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#FFFFFF'

/**
 * 我的页正式版容器。
 *
 * 说明：
 * 1. 未登录场景继续复用原 MineRootTab 的登录 / 注册能力。
 * 2. 已登录场景只展示正式用户中心。
 * 3. 二级页面统一由官方 router.pushUrl 跳转，不在本组件内做 currentView 状态切换。
 */
@Component
export struct MineRootTabClean {
  /** 当前系统内可用的手势分类数量。 */
  @Prop categoryCount: number = 0
  /** 是否只显示登录页。 */
  @Prop loginOnly: boolean = false

  /** 是否已登录。 */
  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false
  /** 当前用户 ID。 */
  @StorageLink('auth.user.id') userId: number = 0
  /** 当前用户名。 */
  @StorageLink('auth.user.username') username: string = ''
  /** 当前用户昵称。 */
  @StorageLink('auth.user.nickname') nickname: string = ''
  /** 当前头像地址。 */
  @StorageLink('auth.user.avatarUrl') avatarUrl: string = ''
  /** 最近练习 ID。 */
  @StorageLink('recent.practice.id') recentPracticeId: number = 0

  /** 最近练习编码。 */
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''

  /** 最近练习名称。 */
  @StorageLink('recent.practice.name') recentPracticeName: string = ''

  /** 最近练习 SiGML 地址。 */
  @StorageLink('recent.practice.sigmlUrl') recentPracticeSigmlUrl: string = ''

  /** 最近练习封面地址。 */
  @StorageLink('recent.practice.coverUrl') recentPracticeCoverUrl: string = ''

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

  /**
   * 判断是否存在可继续的最近练习。
   */
  private hasRecentPractice(): boolean {
    return this.recentPracticeCode.trim().length > 0
  }

  /**
   * 打开最近练习。
   */
  private openRecentPractice(): void {
    if (!this.hasRecentPractice()) {
      return
    }

    try {
      const params: GesturePracticePageParams = new GesturePracticePageParams(
        this.recentPracticeId,
        this.recentPracticeCode,
        this.getRecentPracticeTitle(),
        this.recentPracticeSigmlUrl,
        this.recentPracticeCoverUrl
      )

      router.pushUrl({
        url: 'pages/GesturePracticePageRefactored',
        params: params
      }).catch((err: Object) => {
        console.error(`[MineRootTabClean] open recent practice failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[MineRootTabClean] open recent practice exception: ${JSON.stringify(err)}`)
    }
  }

  /** 构建正式我的页主内容。 */
  @Builder
  private buildMainContent(): void {
    Column({ space: 0 }) {
      MineProfileHeaderCard({
        displayName: this.getDisplayName(),
        username: this.username,
        userId: this.userId,
        avatarUrl: this.avatarUrl,
        avatarText: this.getAvatarText(),
        categoryCount: this.categoryCount,
        recentPracticeTitle: this.getRecentPracticeTitle(),
        recentPracticeEnabled: this.hasRecentPractice(),
        onOpenRecentPractice: (): void => {
          this.openRecentPractice()
        }
      })

      Row()
        .width('100%')
        .height(12)

      MineMenuVisualCard({
        onOpenFavorites: (): void => {},
        onOpenAccountProfile: (): void => {},
        onOpenAccountSecurity: (): void => {},
        onOpenHelpFeedback: (): void => {},
        onOpenAboutHearBridge: (): void => {}
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
        Column() {
          this.buildMainContent()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 16, right: 16, top: this.loginOnly ? 42 : 12, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(PAGE_BG)
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    }
  }
}
