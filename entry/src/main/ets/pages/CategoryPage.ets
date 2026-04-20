import { router } from '@kit.ArkUI'

/**
 * 手势分类类
 */
class GestureCategory {
  id: number
  name: string
  logo: string

  constructor(id: number, name: string, logo: string) {
    this.id = id
    this.name = name
    this.logo = logo
  }
}

@Entry
@Component
struct CategoryPage {
  /**
   * 分类列表
   */
  @State categoryList: GestureCategory[] = [
    new GestureCategory(1, '数字', 'number.png'),
    new GestureCategory(2, '基础手势', 'gesture.png')
  ]

  /**
   * 跳转到手势列表页
   */
  private goToGestureList(item: GestureCategory): void {
    try {
      router.pushUrl({
        url: 'pages/GestureListPage',
        params: {
          categoryId: item.id,
          categoryName: item.name
        }
      }).catch((err: Error) => {
        console.error(`跳转手势列表页失败：${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`跳转手势列表页异常：${JSON.stringify(err)}`)
    }
  }

  build() {
    Column({ space: 16 }) {
      Text('手势分类')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      ForEach(
        this.categoryList,
        (item: GestureCategory) => {
          Button(item.name)
            .width('90%')
            .height(56)
            .fontSize(20)
            .onClick(() => {
              this.goToGestureList(item)
            })
        },
        (item: GestureCategory) => item.id.toString()
      )
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}