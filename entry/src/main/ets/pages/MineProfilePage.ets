import { router } from '@kit.ArkUI'
import { MineProfileEditPage } from '../components/root/MineProfileEditPage'

const TEXT_MAIN: string = '#11233C'
const SECONDARY_TEXT: string = '#6B7A90'
const SURFACE: string = '#FFFFFF'

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

  @Builder
  private buildTopBar(): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor([SECONDARY_TEXT])
      }
      .width(40)
      .height(40)
      .borderRadius(14)
      .backgroundColor(SURFACE)
      .stateEffect(false)
      .onClick(() => {
        this.goBack()
      })

      Text('账号资料')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Blank()
    }
    .width('100%')
  }

  @Builder
  private buildContentArea(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      Scroll() {
        Column() {
          MineProfileEditPage()
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .padding({ left: 0, right: 0, top: 6, bottom: 20 })
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(SURFACE)
      .scrollBar(BarState.Off)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    }
    .width('100%')
    .layoutWeight(1)
    .clip(true)
    .backgroundColor(SURFACE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Column({ space: 16 }) {
      this.buildTopBar()
      this.buildContentArea()
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 0 })
    .backgroundColor(SURFACE)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
