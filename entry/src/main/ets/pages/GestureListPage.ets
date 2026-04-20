import { router } from '@kit.ArkUI'
import { GestureApi } from '../api/GestureApi'
import { GestureItemDto } from '../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../model/GestureModels'

@Entry
@Component
struct GestureListPage {
  @State categoryId: number = 0
  @State categoryName: string = ''
  @State gestureList: GestureItemDto[] = []
  @State loading: boolean = false
  @State errorText: string = ''

  aboutToAppear(): void {
    this.readParams()
    this.loadGestureItems()
  }

  private readParams(): void {
    try {
      let params = router.getParams() as GestureListPageParams
      if (params) {
        this.categoryId = Number(params.categoryId)
        this.categoryName = String(params.categoryName)
      }
    } catch (err) {
      console.error(`读取手势列表页参数失败：${JSON.stringify(err)}`)
    }
  }

  private async loadGestureItems(): Promise<void> {
    this.loading = true
    this.errorText = ''

    try {
      this.gestureList = await GestureApi.getGestureItems(this.categoryId)
      console.error(`手势数量：${this.gestureList.length}`)
    } catch (err) {
      this.errorText = `手势列表加载失败：${JSON.stringify(err)}`
      console.error(this.errorText)
    } finally {
      this.loading = false
    }
  }

  private goBack(): void {
    try {
      router.back()
    } catch (err) {
      console.error(`返回分类页失败：${JSON.stringify(err)}`)
    }
  }

  private goToPractice(item: GestureItemDto): void {
    try {
      let params: GesturePracticePageParams = new GesturePracticePageParams(
        item.id,
        item.chineseName,
        item.label
      )
      router.pushUrl({
        url: 'pages/GesturePracticePage',
        params: params
      }).catch((err: Object) => {
        console.error(`跳转训练页失败：${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`跳转训练页异常：${JSON.stringify(err)}`)
    }
  }

  @Builder
  private buildTopBar(): void {
    Row() {
      Button('返回')
        .fontSize(16)
        .height(40)
        .onClick(() => {
          this.goBack()
        })

      Text(this.categoryName === '' ? '手势列表' : this.categoryName)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private buildGestureItem(item: GestureItemDto): void {
    Row() {
      Column({ space: 6 }) {
        Text(item.chineseName)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)

        Text(`label: ${item.label}`)
          .fontSize(14)
          .fontColor('#888888')
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      Text('训练')
        .fontSize(16)
        .fontColor('#3F7BFF')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F7F8FA')
    .borderRadius(16)
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      this.goToPractice(item)
    })
  }

  build() {
    Column() {
      this.buildTopBar()

      if (this.loading) {
        Column() {
          Text('加载中...')
            .fontSize(18)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else if (this.errorText !== '') {
        Column() {
          Text(this.errorText)
            .fontSize(16)
            .fontColor(Color.Red)
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else if (this.gestureList.length === 0) {
        Column({ space: 8 }) {
          Text('当前分类下还没有手势数据')
            .fontSize(18)
            .fontColor('#666666')

          Text('后面可以继续补这个分类的数据')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else {
        List({ space: 16 }) {
          ForEach(
            this.gestureList,
            (item: GestureItemDto) => {
              ListItem() {
                this.buildGestureItem(item)
              }
            },
            (item: GestureItemDto) => item.id.toString()
          )
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .alignListItem(ListItemAlign.Start)
        .edgeEffect(EdgeEffect.None)
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }
}