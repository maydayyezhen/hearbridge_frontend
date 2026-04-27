import { router } from '@kit.ArkUI'
import { GestureApi } from '../../api/GestureApi'
import { CategoryDto, GestureItemDto } from '../../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#FFFFFF'
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
 * 3. 已提交搜索时调用后端统一搜索接口，同时展示分类和具体手势资源。
 * 4. 视觉语言统一为白底线性列表，减少卡片堆叠感。
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
  /** 搜索中的分类结果。 */
  @State searchedCategories: CategoryDto[] = []
  /** 搜索中的手势资源结果。 */
  @State searchedResources: GestureItemDto[] = []
  /** 是否正在搜索。 */
  @State searching: boolean = false
  /** 搜索错误文案。 */
  @State searchErrorText: string = ''

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
    const keyword = this.keywordInput.trim()
    this.submittedKeyword = keyword
    if (keyword.length === 0) {
      this.searchedCategories = []
      this.searchedResources = []
      this.searchErrorText = ''
      return
    }
    void this.loadSearchResult(keyword)
  }

  /** 加载真实搜索结果。 */
  private async loadSearchResult(keyword: string): Promise<void> {
    if (this.searching) {
      return
    }

    this.searching = true
    this.searchErrorText = ''

    try {
      const result = await GestureApi.search(keyword)
      this.searchedCategories = result.categories
      this.searchedResources = result.resources
    } catch (err) {
      this.searchedCategories = []
      this.searchedResources = []
      this.searchErrorText = `搜索失败：${JSON.stringify(err)}`
    } finally {
      this.searching = false
    }
  }

  /** 获取未搜索时展示的分类列表。 */
  private getDefaultCategories(): CategoryDto[] {
    return this.categories
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

  /** 打开手势训练页。 */
  private openGestureResource(item: GestureItemDto): void {
    try {
      AppStorage.setOrCreate('recent.practice.id', item.id)
      AppStorage.setOrCreate('recent.practice.code', item.code)
      AppStorage.setOrCreate('recent.practice.name', item.nameZh === '' ? item.code : item.nameZh)
      AppStorage.setOrCreate('recent.practice.sigmlUrl', item.sigmlUrl)
      AppStorage.setOrCreate('recent.practice.coverUrl', item.coverUrl)

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
        console.error(`[TrainingRootTab] open resource failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[TrainingRootTab] open resource exception: ${JSON.stringify(err)}`)
    }
  }

  /** 构建分类徽标文字。 */
  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  /** 构建资源徽标文字。 */
  private buildResourceBadgeText(item: GestureItemDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : '练'
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

      TextInput({ text: this.keywordInput, placeholder: '搜索手势或分类' })
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
    .backgroundColor(PAGE_BG)
    .borderRadius(20)
    .border({ width: 1, color: BORDER })
  }

  /** 构建分组标题。 */
  @Builder
  private buildSectionTitle(title: string, count: number): void {
    Row() {
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Text(` ${count}`)
        .fontSize(12)
        .fontColor(TEXT_SUB)

      Blank()
    }
    .width('100%')
    .padding({ top: 6, bottom: 4 })
  }

  /** 构建线性分割线。 */
  @Builder
  private buildDivider(): void {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(BORDER)
  }

  /** 构建分类结果行。 */
  @Builder
  private buildCategoryResultCard(item: CategoryDto): void {
    Column() {
      Row({ space: 14 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.buildBadgeText(item))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(PRIMARY)
        }
        .width(40)
        .height(40)
        .borderRadius(14)
        .backgroundColor(PRIMARY_SOFT)

        Column({ space: 4 }) {
          Text(item.nameZh.trim().length > 0 ? item.nameZh : item.code)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.code)
            .fontSize(12)
            .fontColor(TEXT_SUB)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)

        Text('分类')
          .fontSize(13)
          .fontColor(TEXT_SUB)
      }
      .width('100%')
      .padding({ top: 13, bottom: 13 })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openCategory(item)
      })

      this.buildDivider()
    }
    .width('100%')
    .backgroundColor(PAGE_BG)
  }

  /** 构建手势资源结果行。 */
  @Builder
  private buildResourceResultCard(item: GestureItemDto): void {
    Column() {
      Row({ space: 14 }) {
        if (item.coverUrl !== '') {
          Image(item.coverUrl)
            .width(40)
            .height(40)
            .borderRadius(14)
            .objectFit(ImageFit.Cover)
            .backgroundColor(PRIMARY_SOFT)
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.buildResourceBadgeText(item))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(PRIMARY)
          }
          .width(40)
          .height(40)
          .borderRadius(14)
          .backgroundColor(PRIMARY_SOFT)
        }

        Column({ space: 4 }) {
          Text(item.nameZh.trim().length > 0 ? item.nameZh : item.code)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(TEXT_MAIN)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`${item.code} · ${item.categoryCode}`)
            .fontSize(12)
            .fontColor(TEXT_SUB)
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
        this.openGestureResource(item)
      })

      this.buildDivider()
    }
    .width('100%')
    .backgroundColor(PAGE_BG)
  }

  /** 构建搜索状态区域。 */
  @Builder
  private buildStateCard(title: string, description: string): void {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(TEXT_MAIN)

      Text(description)
        .fontSize(13)
        .lineHeight(21)
        .fontColor(TEXT_SUB)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 32, bottom: 32 })
    .backgroundColor(PAGE_BG)
    .alignItems(HorizontalAlign.Center)
  }

  /** 构建未搜索时的默认内容。 */
  @Builder
  private buildDefaultResults(): void {
    if (this.loading) {
      this.buildStateCard('正在加载训练分类', '稍等一下，我们正在同步当前训练资源。')
    } else if (this.errorText.trim().length > 0) {
      this.buildStateCard('训练分类加载失败', this.errorText)
    } else if (this.getDefaultCategories().length === 0) {
      this.buildStateCard('暂无训练分类', '当前还没有可用训练分类。')
    } else {
      Column({ space: 0 }) {
        this.buildSectionTitle('全部分类', this.getDefaultCategories().length)

        ForEach(
          this.getDefaultCategories(),
          (item: CategoryDto) => {
            this.buildCategoryResultCard(item)
          },
          (item: CategoryDto) => item.id.toString()
        )
      }
      .width('100%')
    }
  }

  /** 构建真实搜索结果。 */
  @Builder
  private buildSubmittedSearchResults(): void {
    if (this.searching) {
      this.buildStateCard('正在搜索', '正在查找匹配的手势和分类。')
    } else if (this.searchErrorText.trim().length > 0) {
      this.buildStateCard('搜索失败', this.searchErrorText)
    } else if (this.searchedResources.length === 0 && this.searchedCategories.length === 0) {
      this.buildStateCard('没有匹配结果', '换个关键词后点击键盘搜索按钮再试试。')
    } else {
      Column({ space: 18 }) {
        if (this.searchedResources.length > 0) {
          Column({ space: 0 }) {
            this.buildSectionTitle('手势资源', this.searchedResources.length)
            ForEach(
              this.searchedResources,
              (item: GestureItemDto) => {
                this.buildResourceResultCard(item)
              },
              (item: GestureItemDto) => item.id.toString()
            )
          }
          .width('100%')
        }

        if (this.searchedCategories.length > 0) {
          Column({ space: 0 }) {
            this.buildSectionTitle('相关分类', this.searchedCategories.length)
            ForEach(
              this.searchedCategories,
              (item: CategoryDto) => {
                this.buildCategoryResultCard(item)
              },
              (item: CategoryDto) => item.id.toString()
            )
          }
          .width('100%')
        }
      }
      .width('100%')
    }
  }

  /** 构建搜索结果区域。 */
  @Builder
  private buildSearchResults(): void {
    if (this.isSearching()) {
      this.buildSubmittedSearchResults()
    } else {
      this.buildDefaultResults()
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
