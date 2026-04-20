import { router } from '@kit.ArkUI'
import { CategoryDto } from '../model/ApiModels'
import { GestureApi } from '../api/GestureApi'
import { GestureListPageParams } from '../model/GestureModels'

@Entry
@Component
struct Index {
  @State categoryList: CategoryDto[] = []
  @State loading: boolean = false
  @State errorText: string = ''

  aboutToAppear(): void {
    this.loadCategories()
  }

  private async loadCategories(): Promise<void> {
    this.loading = true
    this.errorText = ''

    try {
      this.categoryList = await GestureApi.getCategories()
      console.error(`分类数量：${this.categoryList.length}`)
    } catch (err) {
      this.errorText = `分类加载失败：${JSON.stringify(err)}`
      console.error(this.errorText)
    } finally {
      this.loading = false
    }
  }

  private goToGestureList(item: CategoryDto): void {
    try {
      let params: GestureListPageParams = new GestureListPageParams(item.id, item.name)
      router.pushUrl({
        url: 'pages/GestureListPage',
        params: params
      }).catch((err: Object) => {
        console.error(`跳转手势列表页失败：${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`跳转手势列表页异常：${JSON.stringify(err)}`)
    }
  }

  @Builder
  private buildTopBar(): void {
    Row() {
      Text('手势分类')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private buildCategoryItem(item: CategoryDto): void {
    Row() {
      Column({ space: 6 }) {
        Text(item.name)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)

        Text(`logo: ${item.logo}`)
          .fontSize(14)
          .fontColor('#888888')
      }
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Blank()

      Text('进入')
        .fontSize(16)
        .fontColor('#3F7BFF')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F7F8FA')
    .borderRadius(16)
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      this.goToGestureList(item)
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
      } else if (this.categoryList.length === 0) {
        Column() {
          Text('当前没有分类数据')
            .fontSize(18)
            .fontColor('#666666')
        }
        .width('100%')
        .layoutWeight(1)
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Start)
      } else {
        List({ space: 16 }) {
          ForEach(
            this.categoryList,
            (item: CategoryDto) => {
              ListItem() {
                this.buildCategoryItem(item)
              }
            },
            (item: CategoryDto) => item.id.toString()
          )
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 16, bottom: 24 })
        .alignListItem(ListItemAlign.Start)
        .edgeEffect(EdgeEffect.None)
        .scrollBar(BarState.Off)
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