import { CategoryDto } from '../model/ApiModels'
import { GestureApi } from '../api/GestureApi'
import { HomeRootTab } from '../components/root/HomeRootTab'
import { TrainingRootTab } from '../components/root/TrainingRootTab'
import { MineRootTabClean } from '../components/root/MineRootTabClean'
import common from '@ohos.app.ability.common'
import { restoreAuthState } from '../common/auth/AuthStorage'

const PAGE_BG: string = '#F5F7FB'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_ACTIVE: string = '#1D4ED8'
const TEXT_INACTIVE: string = '#8A94A6'

@Entry
@Component
struct Index {
  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false

  @State categoryList: CategoryDto[] = []
  @State loading: boolean = false
  @State errorText: string = ''
  @State currentTabIndex: number = 0

  private tabsController: TabsController = new TabsController()

  aboutToAppear(): void {
    void restoreAuthState(this.getAbilityContext())
    void this.loadCategories()
  }

  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

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

  private switchToTab(index: number): void {
    this.currentTabIndex = index
    try {
      this.tabsController.changeIndex(index)
    } catch (err) {
      console.error(`[Index] switch tab failed: ${JSON.stringify(err)}`)
    }
  }

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
    Column() {
      if (!this.isLoggedIn) {
        MineRootTabClean({
          categoryCount: this.categoryList.length,
          loginOnly: true
        })
      } else {
        Tabs({
          barPosition: BarPosition.End,
          controller: this.tabsController
        }) {
          TabContent() {
            HomeRootTab({
              categories: this.categoryList,
              loading: this.loading,
              errorText: this.errorText,
              onOpenTrainingTab: (): void => {
                this.switchToTab(1)
              }
            })
          }
            .tabBar(this.buildTabItem(0, '首页', $r('sys.symbol.house'), $r('sys.symbol.house_fill')))

          TabContent() {
            TrainingRootTab({
              categories: this.categoryList,
              loading: this.loading,
              errorText: this.errorText
            })
          }
            .tabBar(this.buildTabItem(1, '训练', $r('sys.symbol.fast'), $r('sys.symbol.fast_fill')))

          TabContent() {
            MineRootTabClean({
              categoryCount: this.categoryList.length,
              loginOnly: false
            })
          }
            .tabBar(this.buildTabItem(2, '我的', $r('sys.symbol.person'), $r('sys.symbol.person_fill')))
        }
        .vertical(false)
        .barMode(BarMode.Fixed)
        .backgroundColor('#FFFFFF')
        .onChange((index: number) => {
          this.currentTabIndex = index
        })
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
