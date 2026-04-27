import { router } from '@kit.ArkUI'
import { GestureApi } from '../api/GestureApi'
import { GestureItemDto } from '../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../model/GestureModels'

const TEXT_MAIN: string = '#11233C'
const SECONDARY_TEXT: string = '#6B7A90'
const SURFACE: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const BORDER: string = '#E5EAF3'
const SOFT_BG: string = '#EAF1FF'

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
        url: 'pages/GesturePracticePageRefactored',
        params: params
      }).catch((err: Object) => {
        console.error(`跳转训练页失败：${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`跳转训练页异常：${JSON.stringify(err)}`)
    }
  }

  private getFallbackText(item: GestureItemDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : '练'
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

      Text(this.categoryName === '' ? '资源列表' : this.categoryName)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Blank()
    }
    .width('100%')
  }

  @Builder
  private buildCover(item: GestureItemDto): void {
    if (item.coverUrl !== '') {
      Image(item.coverUrl)
        .width(42)
        .height(42)
        .borderRadius(14)
        .objectFit(ImageFit.Cover)
        .backgroundColor(SOFT_BG)
    } else {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.getFallbackText(item))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY)
          .textAlign(TextAlign.Center)
      }
      .width(42)
      .height(42)
      .borderRadius(14)
      .backgroundColor(SOFT_BG)
    }
  }

  @Builder
  private buildDivider(): void {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(BORDER)
  }

  @Builder
  private buildGestureItem(item: GestureItemDto): void {
    Column() {
      Row({ space: 14 }) {
        this.buildCover(item)

        Column({ space: 4 }) {
          Text(item.nameZh === '' ? item.code : item.nameZh)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${item.code} · ${item.categoryCode}`)
            .fontSize(12)
            .fontColor(SECONDARY_TEXT)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Text('练习')
          .fontSize(13)
          .fontColor(PRIMARY)
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.goToPractice(item)
      })

      this.buildDivider()
    }
    .width('100%')
    .backgroundColor(SURFACE)
  }

  @Builder
  private buildStateContent(title: string, description: string, isError: boolean = false): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(isError ? Color.Red : TEXT_MAIN)

      if (description.trim().length > 0) {
        Text(description)
          .fontSize(13)
          .fontColor(SECONDARY_TEXT)
      }
    }
    .width('100%')
    .padding({ top: 24, bottom: 32 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private buildListContent(): void {
    Scroll() {
      Column({ space: 0 }) {
        ForEach(
          this.gestureList,
          (item: GestureItemDto) => {
            this.buildGestureItem(item)
          },
          (item: GestureItemDto) => item.id.toString()
        )
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 0, right: 0, top: 0, bottom: 20 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(SURFACE)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  @Builder
  private buildContentArea(): void {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.loading) {
        this.buildStateContent('加载中...', '')
      } else if (this.errorText !== '') {
        this.buildStateContent(this.errorText, '', true)
      } else if (this.gestureList.length === 0) {
        this.buildStateContent('当前分类下还没有资源数据', '后续可以继续补充这个分类的手语资源')
      } else {
        this.buildListContent()
      }
    }
    .width('100%')
    .layoutWeight(1)
    .clip(true)
    .backgroundColor(SURFACE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  build() {
    Column({ space: 10 }) {
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
