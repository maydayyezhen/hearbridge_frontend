import { router } from '@kit.ArkUI'
import { CategoryDto } from '../../model/ApiModels'
import { GestureListPageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#FFFFFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'

/**
 * 训练中心根 Tab。
 *
 * 当前定位：
 * 1. 作为训练资源搜索入口，而不是传统说明型首页。
 * 2. 搜索框只负责输入；用户点击键盘搜索按钮后才提交搜索。
 * 3. 搜索范围暂时基于当前已加载分类；后续可接入后端资源搜索接口。
 */
@Component
export struct TrainingRootTab {
  /** 当前可用训练分类。 */
  @Prop categories: CategoryDto[] = []
  /** 分类加载状态。 */
  @Prop loading: boolean = false
  /** 分类加载错误文案。 */
  @Prop errorText: string = ''

  /** 搜索框当前输入内容。 */
  @State keywordInput: string = ''
  /** 已提交的搜索关键词。 */
  @State submittedKeyword: string = ''

  /** 获取已提交搜索关键词。 */
  private getKeyword(): string {
    return this.submittedKeyword.trim().toLowerCase()
  }

  /** 判断当前是否处于已提交搜索状态。 */
  private isSearching(): boolean {
    return this.getKeyword().length > 0
  }

  /** 提交搜索。 */
  private submitSearch(): void {
    this.submittedKeyword = this.keywordInput.trim()
  }

  /** 获取可见分类列表。 */
  private getVisibleCategories(): CategoryDto[] {
    const keyword = this.getKeyword()
    if (keyword.length === 0) {
      return this.categories
    }

    return this.categories.filter((item: CategoryDto) => {
      const name = item.nameZh.toLowerCase()
      const code = item.code.toLowerCase()
      return name.indexOf(keyword) >= 0 || code.indexOf(keyword) >= 0
    })
  }

  /** 打开分类资源列表页。 */
  private openCategory(item: CategoryDto): void {
    try {
      const params: GestureListPageParams = new GestureListPageParams(item.code, item.nameZh)
      router.pushUrl({
        url: 'pages/GestureListPage',
        params: params
      }).catch((err: Object) => {
        console.error(`[TrainingRootTab] open category failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[TrainingRootTab] open category exception: ${JSON.stringify(err)}`)
    }
  }

  /** 构建分类徽标文字。 */
  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  /** 构建搜索栏。 */
  @Builder
  private buildSearchBar(): void {
    Row({ space: 10 }) {
      Stack({ alignContent: Alignment.Center }) {
        Row()
          .width(30)
          .height(30)
          .backgroundColor(PRIMARY_SOFT)
          .borderRadius(15)

        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(15)
          .fontColor([PRIMARY])
      }
      .width(30)
      .height(30)

      TextInput({ text: this.keywordInput, placeholder: '搜索训练分类或编码' })
        .layoutWeight(1)
        .height(38)
        .fontSize(15)
        .backgroundColor(Color.Transparent)
        .placeholderColor('#9AACBF')
        .enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => {
          this.keywordInput = value
        })
        .onSubmit(() => {
          this.submitSearch()
        })
    }
    .width('100%')
    .height(52)
    .padding({ left: 10, right: 14 })
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .border({ width: 1, color: BORDER })
  }

  /** 构建分类结果卡片。 */
  @Builder
  private buildCategoryResultCard(item: CategoryDto): void {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.buildBadgeText(item))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY)
      }
      .width(52)
      .height(52)
      .borderRadius(18)
      .backgroundColor(PRIMARY_SOFT)

      Column({ space: 5 }) {
        Text(item.nameZh.trim().length > 0 ? item.nameZh : item.code)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.code)
          .fontSize(13)
          .fontColor(TEXT_SUB)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)

      Text('进入')
        .fontSize(14)
        .fontColor(PRIMARY)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .border({ width: 1, color: BORDER })
    .onClick(() => {
      this.openCategory(item)
    })
  }

  /** 构建搜索状态卡片。 */
  @Builder
  private buildStateCard(title: string, description: string): void {
    Column({ space: 10 }) {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Text(description)
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TEXT_SUB)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 28, bottom: 28 })
    .backgroundColor(CARD_BG)
    .borderRadius(24)
    .border({ width: 1, color: BORDER })
    .alignItems(HorizontalAlign.Center)
  }

  /** 构建搜索结果区域。 */
  @Builder
  private buildSearchResults(): void {
    if (this.loading) {
      this.buildStateCard('正在加载训练分类', '稍等一下，我们正在同步当前训练资源。')
    } else if (this.errorText.trim().length > 0) {
      this.buildStateCard('训练分类加载失败', this.errorText)
    } else if (this.getVisibleCategories().length === 0) {
      this.buildStateCard('没有匹配结果', this.isSearching() ? '换个关键词后点击键盘搜索按钮再试试。' : '当前还没有可用训练分类。')
    } else {
      Column({ space: 14 }) {
        ForEach(
          this.getVisibleCategories(),
          (item: CategoryDto) => {
            this.buildCategoryResultCard(item)
          },
          (item: CategoryDto) => item.id.toString()
        )
      }
      .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        this.buildSearchBar()
        this.buildSearchResults()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
