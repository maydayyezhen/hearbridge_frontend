import { router } from '@kit.ArkUI'
import { CategoryDto } from '../../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#FFFFFF'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'
const SURFACE_SOFT: string = '#F7F8FA'

/**
 * 训练中心根 Tab。
 *
 * 当前定位：
 * 1. 作为训练资源搜索入口，而不是传统分类首页。
 * 2. 搜索范围暂时基于当前已加载分类；后续可接入后端资源搜索接口。
 * 3. 点击分类进入具体手势资源列表，点击最近练习直接进入训练页。
 */
@Component
export struct TrainingRootTab {
  /** 当前可用训练分类。 */
  @Prop categories: CategoryDto[] = []
  /** 分类加载状态。 */
  @Prop loading: boolean = false
  /** 分类加载错误文案。 */
  @Prop errorText: string = ''

  /** 搜索关键词。 */
  @State keyword: string = ''

  /** 最近练习资源 ID。 */
  @StorageLink('recent.practice.id') recentPracticeId: number = 0
  /** 最近练习资源编码。 */
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''
  /** 最近练习资源名称。 */
  @StorageLink('recent.practice.name') recentPracticeName: string = ''
  /** 最近练习 SiGML 地址。 */
  @StorageLink('recent.practice.sigmlUrl') recentPracticeSigmlUrl: string = ''
  /** 最近练习封面地址。 */
  @StorageLink('recent.practice.coverUrl') recentPracticeCoverUrl: string = ''

  /** 判断是否存在最近练习。 */
  private hasRecentPractice(): boolean {
    return this.recentPracticeCode.trim().length > 0 && this.recentPracticeSigmlUrl.trim().length > 0
  }

  /** 获取最近练习标题。 */
  private getRecentPracticeTitle(): string {
    return this.recentPracticeName.trim().length > 0 ? this.recentPracticeName : this.recentPracticeCode
  }

  /** 获取搜索关键词。 */
  private getKeyword(): string {
    return this.keyword.trim().toLowerCase()
  }

  /** 判断当前是否处于搜索状态。 */
  private isSearching(): boolean {
    return this.getKeyword().length > 0
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

  /** 继续最近一次练习。 */
  private continueRecentPractice(): void {
    if (!this.hasRecentPractice()) {
      return
    }

    try {
      const params: GesturePracticePageParams = new GesturePracticePageParams(
        this.recentPracticeId,
        this.recentPracticeCode,
        this.getRecentPracticeTitle(),
        this.recentPracticeSigmlUrl,
        this.recentPracticeCoverUrl
      )
      router.pushUrl({
        url: 'pages/GesturePracticePageRefactored',
        params: params
      }).catch((err: Object) => {
        console.error(`[TrainingRootTab] continue practice failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[TrainingRootTab] continue practice exception: ${JSON.stringify(err)}`)
    }
  }

  /** 清空搜索关键词。 */
  private clearKeyword(): void {
    this.keyword = ''
  }

  /** 构建分类徽标文字。 */
  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  /** 构建顶部搜索区。 */
  @Builder
  private buildSearchHero(): void {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text('训练搜索')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Text('搜索分类，快速进入对应的手语资源与相机训练。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor(TEXT_SUB)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row({ space: 10 }) {
        TextInput({ text: this.keyword, placeholder: '搜索训练分类或编码' })
          .layoutWeight(1)
          .height(48)
          .backgroundColor(CARD_BG)
          .borderRadius(18)
          .fontSize(15)
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: BORDER })
          .onChange((value: string) => {
            this.keyword = value
          })

        if (this.isSearching()) {
          Button('清除')
            .height(48)
            .padding({ left: 16, right: 16 })
            .fontSize(14)
            .fontColor(PRIMARY)
            .backgroundColor(PRIMARY_SOFT)
            .borderRadius(18)
            .stateEffect(false)
            .onClick(() => {
              this.clearKeyword()
            })
        }
      }
      .width('100%')

      Row() {
        Text(this.isSearching()
          ? `找到 ${this.getVisibleCategories().length} 个匹配分类`
          : `当前共有 ${this.categories.length} 个训练分类`)
          .fontSize(12)
          .fontColor(TEXT_SUB)

        Blank()
      }
      .width('100%')
    }
    .width('100%')
  }

  /** 构建最近练习卡片。 */
  @Builder
  private buildRecentPracticeCard(): void {
    Row({ space: 14 }) {
      Column({ space: 5 }) {
        Text('继续上次')
          .fontSize(13)
          .fontColor(TEXT_SUB)

        Text(this.getRecentPracticeTitle())
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`目标编码：${this.recentPracticeCode}`)
          .fontSize(13)
          .fontColor(TEXT_SUB)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('继续')
        .height(40)
        .padding({ left: 18, right: 18 })
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY)
        .borderRadius(20)
        .onClick(() => {
          this.continueRecentPractice()
        })
    }
    .width('100%')
    .padding(18)
    .backgroundColor(CARD_BG)
    .borderRadius(22)
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
    Column({ space: 14 }) {
      Row() {
        Text(this.isSearching() ? '搜索结果' : '全部分类')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()
      }
      .width('100%')

      if (this.loading) {
        this.buildStateCard('正在加载训练分类', '稍等一下，我们正在同步当前训练资源。')
      } else if (this.errorText.trim().length > 0) {
        this.buildStateCard('训练分类加载失败', this.errorText)
      } else if (this.getVisibleCategories().length === 0) {
        this.buildStateCard('没有匹配结果', '换个关键词试试，或者清空搜索查看全部分类。')
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
    .width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildSearchHero()

        if (this.hasRecentPractice() && !this.isSearching()) {
          this.buildRecentPracticeCard()
        }

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
