import { router } from '@kit.ArkUI'
import { GestureApi } from '../api/GestureApi'
import { GestureItemDto } from '../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../model/GestureModels'

@Entry
@Component
struct GestureListPage {
  @State categoryCode: string = ''
  @State categoryName: string = ''
  @State gestureList: GestureItemDto[] = []
  @State loading: boolean = false
  @State errorText: string = ''

  aboutToAppear(): void {
    this.readParams()
    void this.loadGestureItems()
  }

  private readParams(): void {
    try {
      const params = router.getParams() as GestureListPageParams
      if (params) {
        this.categoryCode = String(params.categoryCode)
        this.categoryName = String(params.categoryName)
      }
    } catch (err) {
      console.error(`读取资源列表页参数失败：${JSON.stringify(err)}`)
    }
  }

  private async loadGestureItems(): Promise<void> {
    this.loading = true
    this.errorText = ''

    try {
      this.gestureList = await GestureApi.getGestureItems(this.categoryCode)
      console.info(`[GestureListPage] resource count=${this.gestureList.length}`)
    } catch (err) {
      this.errorText = `资源列表加载失败：${JSON.stringify(err)}`
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

  private persistRecentPractice(item: GestureItemDto): void {
    AppStorage.setOrCreate('recent.practice.id', item.id)
    AppStorage.setOrCreate('recent.practice.code', item.code)
    AppStorage.setOrCreate('recent.practice.name', item.nameZh === '' ? item.code : item.nameZh)
    AppStorage.setOrCreate('recent.practice.sigmlUrl', item.sigmlUrl)
    AppStorage.setOrCreate('recent.practice.coverUrl', item.coverUrl)
  }

  private goToPractice(item: GestureItemDto): void {
    try {
      this.persistRecentPractice(item)
      const params: GesturePracticePageParams = new GesturePracticePageParams(
        item.id,
        item.code,
        item.nameZh === '' ? item.code : item.nameZh,
        item.sigmlUrl,
        item.coverUrl
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

      Text(this.categoryName === '' ? '资源列表' : this.categoryName)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ left: 16 })

      Button('采集')
        .fontSize(15)
        .height(38)
        .margin({ right: 8 })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/DatasetCollectPage'
          }).catch((err: Object) => {
            console.error(`跳转采集页失败：${JSON.stringify(err)}`)
          })
        })

      Blank()
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 12 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private buildCover(item: GestureItemDto): void {
    if (item.coverUrl !== '') {
      Image(item.coverUrl)
        .width(72)
        .height(72)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#EDEFF2')
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Text(item.code)
          .fontSize(12)
          .fontColor('#666666')
          .textAlign(TextAlign.Center)
      }
      .width(72)
      .height(72)
      .borderRadius(12)
      .backgroundColor('#EDEFF2')
    }
  }

  @Builder
  private buildGestureItem(item: GestureItemDto): void {
    Row({ space: 14 }) {
      this.buildCover(item)

      Column({ space: 6 }) {
        Text(item.nameZh === '' ? item.code : item.nameZh)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`编码：${item.code}`)
          .fontSize(14)
          .fontColor('#888888')

        Text(`分类：${item.categoryCode}`)
          .fontSize(13)
          .fontColor('#AAAAAA')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Text('练习')
        .fontSize(16)
        .fontColor('#3F7BFF')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#F7F8FA')
    .borderRadius(16)
    .alignItems(VerticalAlign.Center)
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
          Text('当前分类下还没有资源数据')
            .fontSize(18)
            .fontColor('#666666')

          Text('后续可以继续补充这个分类的手语资源')
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
