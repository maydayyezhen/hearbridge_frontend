import { router } from '@kit.ArkUI'

@Builder
function EmptyBuilder() {
}

@Component
export struct PageScaffold {
  title: string = ''
  showBack: boolean = true

  @BuilderParam content: () => void = EmptyBuilder

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`页面返回失败：${JSON.stringify(err)}`)
    }
  }

  build() {
    Column() {
      Row() {
        if (this.showBack) {
          Button('返回')
            .fontSize(16)
            .height(40)
            .onClick(() => {
              this.goBack()
            })
        }

        Text(this.title)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: this.showBack ? 16 : 0 })

        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor('#FFFFFF')

      Column() {
        this.content()
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}