import { router } from '@kit.ArkUI'
import { MineProfileEditPage } from '../components/root/MineProfileEditPage'

/**
 * 我的 / 账号资料页面。
 */
@Entry
@Component
struct MineProfilePage {
  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回我的页失败：${JSON.stringify(err)}`)
    }
  }

  build() {
    Scroll() {
      MineProfileEditPage({
        onBack: (): void => {
          this.goBack()
        }
      })
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8FBFF')
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
