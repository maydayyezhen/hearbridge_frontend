import { MineProfileEditPage } from './MineProfileEditPage'
import { MineRootTabClean } from './MineRootTabClean'

/**
 * 我的页路由外壳。
 *
 * 说明：
 * 1. main 视图继续交给 MineRootTabClean。
 * 2. profile 视图进入账号资料编辑页。
 * 3. 用 AppStorage 做轻量内部路由，避免继续扩大 MineRootTabClean 的职责。
 */
@Component
export struct MineRootTabRouter {
  /** 当前系统内可用的手势分类数量。 */
  @Prop categoryCount: number = 0
  /** 是否只显示登录页。 */
  @Prop loginOnly: boolean = false
  /** 是否已登录。 */
  @StorageLink('auth.isLoggedIn') isLoggedIn: boolean = false
  /** 我的页当前外层视图。 */
  @StorageLink('mine.currentView') currentView: string = 'main'

  aboutToAppear(): void {
    AppStorage.setOrCreate('mine.currentView', 'main')
  }

  build() {
    if (this.isLoggedIn && this.currentView === 'profile') {
      Scroll() {
        MineProfileEditPage({
          onBack: (): void => {
            AppStorage.setOrCreate('mine.currentView', 'main')
          }
        })
        .width('100%')
        .padding({ left: 16, right: 16, top: this.loginOnly ? 42 : 16, bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8FBFF')
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
    } else {
      MineRootTabClean({
        categoryCount: this.categoryCount,
        loginOnly: this.loginOnly
      })
    }
  }
}
