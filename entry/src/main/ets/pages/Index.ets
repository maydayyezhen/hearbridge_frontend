import common from '@ohos.app.ability.common'
import { CategoryDto } from '../model/ApiModels'
import { GestureApi } from '../api/GestureApi'
import { HomeRootTab } from '../components/root/HomeRootTab'
import { TrainingRootTab } from '../components/root/TrainingRootTab'
import { MineRootTabClean } from '../components/root/MineRootTabClean'
import { restoreAuthState } from '../common/auth/AuthStorage'
import { restoreRecentPracticeFromBackend } from '../common/practice/RecentPracticeStorage'

const PAGE_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_ACTIVE: string = '#1D4ED8'
const TEXT_INACTIVE: string = '#8A94A6'
const TAB_BORDER: string = '#EEF1F5'

/**
 * App 首页入口。
 *
 * 说明：
 * 1. 未登录时只展示登录 / 注册页。
 * 2. 已登录时展示首页、训练、我的三个底部 Tab。
 * 3. 启动时恢复登录态、最近练习，并加载手语分类。
 * 4. 底部 TabBar 使用 divider 显示顶部灰色分隔线。
 */
@Entry
@Component
struct Index {
  /** 当前是否已登录。 */
  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false

  /** 首页与训练页共用的分类列表。 */
  @State categoryList: CategoryDto[] = []

  /** 分类是否正在加载。 */
  @State loading: boolean = false

  /** 分类加载错误文案。 */
  @State errorText: string = ''

  /** 当前选中的底部 Tab 下标。 */
  @State currentTabIndex: number = 0

  /** Tabs 控制器。 */
  private tabsController: TabsController = new TabsController()

  aboutToAppear(): void {
    void this.initPage()
  }

  /**
   * 初始化页面数据。
   */
  private async initPage(): Promise<void> {
    await restoreAuthState(this.getAbilityContext())
    await restoreRecentPracticeFromBackend()
    void this.loadCategories()
  }

  /**
   * 获取当前 Ability 上下文。
   */
  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

  /**
   * 加载手语分类。
   */
  private async loadCategories(): Promise<void> {
    this.loading = true
    this.errorText = ''

    try {
      this.categoryList = await GestureApi.getCategories()
      console.info(`[Index] category count=${this.categoryList.length}`)
    } catch (err) {
      this.errorText = `分类加载失败：${JSON.stringify(err)}`
      console.error(this.errorText)
    } finally {
      this.loading = false
    }
  }

  /**
   * 切换底部 Tab。
   */
  private switchToTab(index: number): void {
    this.currentTabIndex = index

    try {
      this.tabsController.changeIndex(index)
    } catch (err) {
      console.error(`[Index] switch tab failed: ${JSON.stringify(err)}`)
    }
  }

  /**
   * 构建底部 Tab 项。
   */
  @Builder
  private buildTabItem(index: number, label: string, icon: Resource, selectedIcon: Resource): void {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row() {}
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor(this.currentTabIndex === index ? PRIMARY_SOFT : 'transparent')

        SymbolGlyph(this.currentTabIndex === index ? selectedIcon : icon)
          .fontSize(19)
          .fontColor(this.currentTabIndex === index ? [PRIMARY] : ['#8A94A6'])
      }
      .width(34)
      .height(34)

      Text(label)
        .fontSize(11)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTabIndex === index ? TEXT_ACTIVE : TEXT_INACTIVE)
    }
    .width('100%')
    .height(58)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        if (!this.isLoggedIn) {
          Stack({ alignContent: Alignment.TopStart }) {
            MineRootTabClean({
              categoryCount: this.categoryList.length,
              loginOnly: true
            })
          }
          .width('100%')
          .height('100%')
        } else {
          Tabs({
            barPosition: BarPosition.End,
            controller: this.tabsController
          }) {
            TabContent() {
              Stack({ alignContent: Alignment.TopStart }) {
                HomeRootTab({
                  categories: this.categoryList,
                  loading: this.loading,
                  errorText: this.errorText,
                  onOpenTrainingTab: (): void => {
                    this.switchToTab(1)
                  }
                })
              }
              .width('100%')
              .height('100%')
            }
            .tabBar(this.buildTabItem(0, '首页', $r('sys.symbol.house'), $r('sys.symbol.house_fill')))

            TabContent() {
              Stack({ alignContent: Alignment.TopStart }) {
                TrainingRootTab({
                  categories: this.categoryList,
                  loading: this.loading,
                  errorText: this.errorText
                })
              }
              .width('100%')
              .height('100%')
            }
            .tabBar(this.buildTabItem(1, '训练', $r('sys.symbol.fast'), $r('sys.symbol.fast_fill')))

            TabContent() {
              Stack({ alignContent: Alignment.TopStart }) {
                MineRootTabClean({
                  categoryCount: this.categoryList.length,
                  loginOnly: false
                })
              }
              .width('100%')
              .height('100%')
            }
            .tabBar(this.buildTabItem(2, '我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill')))
          }
          .vertical(false)
          .barMode(BarMode.Fixed)
          .backgroundColor('#FFFFFF')
          .divider({
            strokeWidth: 0.5,
            color: TAB_BORDER
          })
          .onChange((index: number) => {
            this.currentTabIndex = index
          })
          .width('100%')
          .layoutWeight(1)
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(PAGE_BG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}