import { router } from '@kit.ArkUI'
import { CategoryDto } from '../../model/ApiModels'
import { GestureListPageParams, GesturePracticePageParams } from '../../model/GestureModels'

const PAGE_BG: string = '#F5F7FB'
const CARD_BG: string = '#FFFFFF'
const PRIMARY: string = '#2D6CDF'
const PRIMARY_SOFT: string = '#EAF1FF'
const TEXT_MAIN: string = '#111827'
const TEXT_SUB: string = '#667085'
const BORDER: string = '#E5EAF3'

@Component
export struct HomeRootTab {
  @Prop categories: CategoryDto[] = []
  @Prop loading: boolean = false
  @Prop errorText: string = ''
  onOpenTrainingTab: () => void = () => {}

  @StorageLink('recent.practice.id') recentPracticeId: number = 0
  @StorageLink('recent.practice.code') recentPracticeCode: string = ''
  @StorageLink('recent.practice.name') recentPracticeName: string = ''
  @StorageLink('recent.practice.sigmlUrl') recentPracticeSigmlUrl: string = ''
  @StorageLink('recent.practice.coverUrl') recentPracticeCoverUrl: string = ''

  private getGreeting(): string {
    const hour = new Date().getHours()
    if (hour < 11) {
      return '早上好，开始今天的手语练习'
    }
    if (hour < 18) {
      return '下午好，继续熟悉新的手语动作'
    }
    return '晚上好，用几分钟完成一轮练习'
  }

  private hasRecentPractice(): boolean {
    return this.recentPracticeCode.trim().length > 0 && this.recentPracticeSigmlUrl.trim().length > 0
  }

  private getRecentPracticeTitle(): string {
    return this.recentPracticeName.trim().length > 0 ? this.recentPracticeName : this.recentPracticeCode
  }

  private openCategory(item: CategoryDto): void {
    try {
      const params: GestureListPageParams = new GestureListPageParams(item.code, item.nameZh)
      router.pushUrl({
        url: 'pages/GestureListPage',
        params: params
      }).catch((err: Object) => {
        console.error(`[HomeRootTab] open category failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[HomeRootTab] open category exception: ${JSON.stringify(err)}`)
    }
  }

  private continueRecentPractice(): void {
    if (!this.hasRecentPractice()) {
      if (this.categories.length > 0) {
        this.openCategory(this.categories[0])
      } else {
        this.onOpenTrainingTab()
      }
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
        console.error(`[HomeRootTab] continue practice failed: ${JSON.stringify(err)}`)
      })
    } catch (err) {
      console.error(`[HomeRootTab] continue practice exception: ${JSON.stringify(err)}`)
    }
  }

  private buildBadgeText(item: CategoryDto): string {
    const source = item.nameZh.trim().length > 0 ? item.nameZh : item.code
    return source.length > 0 ? source.slice(0, 1).toUpperCase() : 'S'
  }

  private getFeaturedCategories(): CategoryDto[] {
    return this.categories.slice(0, 4)
  }

  @Builder
  private buildHeroCard(): void {
    Column({ space: 18 }) {
      Column({ space: 8 }) {
        Text('HearBridge')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#DCEAFF')

        Text(this.getGreeting())
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Text('分类浏览、数字人演示和相机识别已经连通，直接从这里开始。')
          .fontSize(14)
          .lineHeight(22)
          .fontColor('#EAF1FF')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      Row({ space: 12 }) {
        Button(this.hasRecentPractice() ? '继续上次练习' : '开始训练')
          .layoutWeight(1)
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(PRIMARY)
          .backgroundColor('#FFFFFF')
          .borderRadius(23)
          .onClick(() => {
            this.continueRecentPractice()
          })

        Button('浏览分类')
          .layoutWeight(1)
          .height(46)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('rgba(255,255,255,0.16)')
          .borderRadius(23)
          .border({
            width: 1,
            color: 'rgba(255,255,255,0.24)'
          })
          .onClick(() => {
            this.onOpenTrainingTab()
          })
      }
      .width('100%')

      Row({ space: 12 }) {
        this.buildMiniStat('分类', `${this.categories.length}`)
        this.buildMiniStat('数字人', '已接通')
        this.buildMiniStat('识别', '可训练')
      }
      .width('100%')
    }
    .width('100%')
    .padding(22)
    .linearGradient({
      angle: 135,
      colors: [['#4B8BFF', 0], ['#2D6CDF', 1]]
    })
    .borderRadius(28)
  }

  @Builder
  private buildMiniStat(label: string, value: string): void {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')

      Text(label)
        .fontSize(12)
        .fontColor('#DCEAFF')
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor('rgba(255,255,255,0.12)')
    .borderRadius(18)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildContinueCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text('继续练习')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()

        Text('最近一次')
          .fontSize(12)
          .fontColor(TEXT_SUB)
      }
      .width('100%')

      Row({ space: 14 }) {
        if (this.recentPracticeCoverUrl.trim().length > 0) {
          Image(this.recentPracticeCoverUrl)
            .width(92)
            .height(92)
            .borderRadius(20)
            .objectFit(ImageFit.Cover)
            .backgroundColor('#F3F6FB')
        } else {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.recentPracticeCode.trim().length > 0 ? this.recentPracticeCode.toUpperCase() : 'SIGN')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#6B7280')
          }
          .width(92)
          .height(92)
          .borderRadius(20)
          .backgroundColor('#F3F6FB')
        }

        Column({ space: 8 }) {
          Text(this.getRecentPracticeTitle())
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(TEXT_MAIN)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`目标编码：${this.recentPracticeCode}`)
            .fontSize(14)
            .fontColor(TEXT_SUB)

          Text('直接回到数字人和相机练习页面')
            .fontSize(13)
            .fontColor('#8A94A6')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')

      Button('继续练习')
        .width('100%')
        .height(46)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(PRIMARY)
        .borderRadius(23)
        .onClick(() => {
          this.continueRecentPractice()
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(CARD_BG)
    .borderRadius(24)
  }

  @Builder
  private buildFeaturedCategory(item: CategoryDto): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.buildBadgeText(item))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(PRIMARY)
      }
      .width(42)
      .height(42)
      .borderRadius(21)
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

      Text('进入')
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
  private buildCategorySection(): void {
    Column({ space: 14 }) {
      Row() {
        Text('常用分类')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)

        Blank()

        Text('查看全部')
          .fontSize(13)
          .fontColor(PRIMARY)
          .onClick(() => {
            this.onOpenTrainingTab()
          })
      }
      .width('100%')

      ForEach(
        this.getFeaturedCategories(),
        (item: CategoryDto) => {
          this.buildFeaturedCategory(item)
        },
        (item: CategoryDto) => item.id.toString()
      )
    }
    .width('100%')
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
        this.buildHeroCard()

        if (this.loading) {
          this.buildStateCard('正在加载分类', '稍等一下，我们正在同步当前可用的手语分类。')
        } else if (this.errorText.trim().length > 0) {
          this.buildStateCard('分类加载失败', this.errorText)
        } else {
          if (this.hasRecentPractice()) {
            this.buildContinueCard()
          }

          if (this.categories.length > 0) {
            this.buildCategorySection()
          } else {
            this.buildStateCard('当前还没有分类', '后端资源已经接通后，这里会显示可用的训练分类。')
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(PAGE_BG)
    .scrollBar(BarState.Off)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
