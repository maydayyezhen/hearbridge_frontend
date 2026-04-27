import { router } from '@kit.ArkUI'
import { CategoryDto } from '../../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#F5F7FB'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'

@Component
export struct TrainingRootTab {
  @Prop categories: CategoryDto[] = []
  @Prop loading: boolean = false
  @Prop errorText: string = ''

  @State keyword: string = ''

  @StorageLink('recent.practice.id') recentPracticeId: number = 0
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''
  @StorageLink('recent.practice.name') recentPracticeName: string = ''
  @StorageLink('recent.practice.sigmlUrl') recentPracticeSigmlUrl: string = ''
  @StorageLink('recent.practice.coverUrl') recentPracticeCoverUrl: string = ''

  private hasRecentPractice(): boolean {
    return this.recentPracticeCode.trim().length > 0 && this.recentPracticeSigmlUrl.trim().length > 0
  }

  private getRecentPracticeTitle(): string {
    return this.recentPracticeName.trim().length > 0 ? this.recentPracticeName : this.recentPracticeCode
  }

  private getVisibleCategories(): CategoryDto[] {
    const keyword = this.keyword.trim().toLowerCase()
    if (keyword.length === 0) {
      return this.categories
    }

    return this.categories.filter((item: CategoryDto) => {
      const name = item.nameZh.toLowerCase()
      const code = item.code.toLowerCase()
      return name.indexOf(keyword) >= 0 || code.indexOf(keyword) >= 0
    })
  }

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
        url: 'pages/GesturePracticePage',
        params: params
      }).catch((err: Object) => {
        console.error(`[TrainingRootTab] continue practice failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[TrainingRootTab] continue practice exception: ${JSON.stringify(err)}`)
    }
  }

  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  @Builder
  private buildHeader(): void {
    Column({ space: 8 }) {
      Text('训练中心')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)

      Text('从分类进入练习，或者继续上一次数字人与相机训练。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor(TEXT_SUB)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildRecentPracticeCard(): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text('继续上次')
          .fontSize(13)
          .fontColor(TEXT_SUB)

        Text(this.getRecentPracticeTitle())
          .fontSize(22)
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
  }

  @Builder
  private buildSearchBox(): void {
    Column({ space: 10 }) {
      TextInput({ text: this.keyword, placeholder: '搜索分类名称或编码' })
        .width('100%')
        .height(46)
        .backgroundColor(CARD_BG)
        .borderRadius(18)
        .fontSize(15)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.keyword = value
        })

      Text(`共 ${this.getVisibleCategories().length} 个可用分类`)
        .fontSize(12)
        .fontColor(TEXT_SUB)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildCategoryCard(item: CategoryDto): void {
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

      Text('开始')
        .fontSize(14)
        .fontColor(PRIMARY)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(CARD_BG)
    .borderRadius(20)
    .onClick(() => {
      this.openCategory(item)
    })
  }

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
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        this.buildHeader()

        if (this.hasRecentPractice()) {
          this.buildRecentPracticeCard()
        }

        this.buildSearchBox()

        if (this.loading) {
          this.buildStateCard('正在加载训练分类', '稍等一下，我们正在同步当前训练资源。')
        } else if (this.errorText.trim().length > 0) {
          this.buildStateCard('训练分类加载失败', this.errorText)
        } else if (this.getVisibleCategories().length === 0) {
          this.buildStateCard('没有匹配结果', '换个关键词试试，或者直接清空搜索看看全部分类。')
        } else {
          Column({ space: 14 }) {
            ForEach(
              this.getVisibleCategories(),
              (item: CategoryDto) => {
                this.buildCategoryCard(item)
              },
              (item: CategoryDto) => item.id.toString()
            )
          }
          .width('100%')
        }
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
