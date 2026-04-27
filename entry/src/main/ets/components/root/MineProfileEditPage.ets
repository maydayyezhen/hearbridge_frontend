import common from '@ohos.app.ability.common'
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { router } from '@kit.ArkUI'
import { AuthApi } from '../../api/AuthApi'
import { clearAuthState, saveUserState } from '../../common/auth/AuthStorage'
import { readAvatarBytes, resolveAvatarFileName, resolveAvatarMimeType } from '../../common/file/AvatarFileReader'
import { MineProfileEditVisualCard } from './MineProfileVisualCards'

const PAGE_BG: string = '#FFFFFF'
const TEXT_MAIN: string = '#11233C'

/**
 * 我的页账号资料编辑页面。
 */
@Component
export struct MineProfileEditPage {
  /** 当前登录 token。 */
  @StorageLink('auth.token') token: string = ''
  /** 当前用户昵称。 */
  @StorageLink('auth.user.nickname') nickname: string = ''
  /** 当前用户头像地址。 */
  @StorageLink('auth.user.avatarUrl') avatarUrl: string = ''

  /** 编辑中的昵称。 */
  @State editNickname: string = ''
  /** 已选择但尚未上传的头像 URI。 */
  @State selectedAvatarUri: string = ''
  /** 页面提示文案。 */
  @State pageTip: string = ''
  /** 头像提示文案。 */
  @State avatarTip: string = ''
  /** 是否正在保存资料。 */
  @State savingProfile: boolean = false
  /** 是否正在选择头像。 */
  @State pickingAvatar: boolean = false
  /** 是否正在上传头像。 */
  @State uploadingAvatar: boolean = false
  /** 是否正在退出登录。 */
  @State loggingOut: boolean = false

  /** 返回上一页回调。 */
  onBack: () => void = () => {}

  aboutToAppear(): void {
    this.editNickname = this.nickname
  }

  /** 获取当前 Ability 上下文。 */
  private getAbilityContext(): common.BaseContext {
    return this.getUIContext().getHostContext() as common.BaseContext
  }

  /** 获取头像文字兜底。 */
  private getAvatarText(): string {
    const source = this.nickname.trim().length > 0 ? this.nickname : 'H'
    return source.slice(0, 1).toUpperCase()
  }

  /** 获取当前实际展示的头像地址。 */
  private getVisibleAvatarUri(): string {
    if (this.selectedAvatarUri.trim().length > 0) {
      return this.selectedAvatarUri
    }
    return this.avatarUrl
  }

  /** 保存账号资料。 */
  private async handleSaveProfile(): Promise<void> {
    if (this.savingProfile) {
      return
    }

    const nickname = this.editNickname.trim()
    if (nickname.length === 0) {
      this.pageTip = '昵称不能为空。'
      return
    }
    if (this.token.trim().length === 0) {
      this.pageTip = '登录状态已失效，请重新登录。'
      return
    }

    this.savingProfile = true
    this.pageTip = '正在保存资料...'

    try {
      const user = await AuthApi.updateProfile(this.token, nickname)
      await saveUserState(this.getAbilityContext(), user)
      this.editNickname = user.nickname
      this.pageTip = '资料已更新。'
    } catch (err) {
      this.pageTip = `保存失败：${JSON.stringify(err)}`
    } finally {
      this.savingProfile = false
    }
  }

  /** 从系统相册选择头像。 */
  private async handlePickAvatar(): Promise<void> {
    if (this.pickingAvatar || this.uploadingAvatar) {
      return
    }

    this.pickingAvatar = true
    this.avatarTip = '正在打开相册...'

    try {
      let photoPicker = new photoAccessHelper.PhotoViewPicker()
      let pickerOptions = new photoAccessHelper.PhotoSelectOptions()
      pickerOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      pickerOptions.maxSelectNumber = 1
      const pickerResult = await photoPicker.select(pickerOptions)

      if (pickerResult.photoUris.length > 0) {
        this.selectedAvatarUri = pickerResult.photoUris[0].split('#')[0].split('?')[0]
        this.avatarTip = '已选择图片，点击上传即可保存头像。'
      } else {
        this.avatarTip = '没有选择图片。'
      }
    } catch (_err) {
      this.avatarTip = '当前环境不支持相册读取，请在真机重试。'
    } finally {
      this.pickingAvatar = false
    }
  }

  /** 上传头像并刷新本地用户状态。 */
  private async handleUploadAvatar(): Promise<void> {
    if (this.uploadingAvatar || this.selectedAvatarUri.trim().length === 0) {
      if (this.selectedAvatarUri.trim().length === 0) {
        this.avatarTip = '请先选择一张头像图片。'
      }
      return
    }
    if (this.token.trim().length === 0) {
      this.avatarTip = '登录状态已失效，请重新登录。'
      return
    }

    this.uploadingAvatar = true
    this.avatarTip = '正在上传头像...'

    try {
      const fileName = resolveAvatarFileName(this.selectedAvatarUri)
      const mimeType = resolveAvatarMimeType(fileName)
      const bytes = await readAvatarBytes(this.getAbilityContext() as common.UIAbilityContext, this.selectedAvatarUri)

      if (bytes.byteLength <= 0) {
        this.avatarTip = '图片读取失败，请重新选择。'
        return
      }

      const user = await AuthApi.uploadAvatar(this.token, fileName, mimeType, bytes)
      await saveUserState(this.getAbilityContext(), user)
      this.selectedAvatarUri = ''
      this.avatarTip = '头像已上传。'
    } catch (err) {
      this.avatarTip = `头像上传失败：${JSON.stringify(err)}`
    } finally {
      this.uploadingAvatar = false
    }
  }

  /** 退出登录。 */
  private async handleLogout(): Promise<void> {
    if (this.loggingOut) {
      return
    }

    this.loggingOut = true
    this.pageTip = '正在退出登录...'

    try {
      if (this.token.trim().length > 0) {
        await AuthApi.logout(this.token)
      }
    } catch (_err) {
    }

    await clearAuthState(this.getAbilityContext())
    this.loggingOut = false
    router.back()
  }

  /** 构建页面头部。 */
  @Builder
  private buildPageHeader(): void {
    Row({ space: 12 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_backward'))
          .fontSize(22)
          .fontColor(['#6B7A90'])
      }
      .width(40)
      .height(40)
      .borderRadius(14)
      .backgroundColor('#FFFFFF')
      .stateEffect(false)
      .onClick(() => {
        this.onBack()
      })

      Text('账号资料')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(TEXT_MAIN)
    }
    .width('100%')
  }

  build() {
    Column({ space: 16 }) {
      this.buildPageHeader()

      MineProfileEditVisualCard({
        avatarUrl: this.getVisibleAvatarUri(),
        avatarText: this.getAvatarText(),
        avatarTip: this.avatarTip,
        editNickname: this.editNickname,
        tipText: this.pageTip,
        pickingAvatar: this.pickingAvatar,
        uploadingAvatar: this.uploadingAvatar,
        submitting: this.savingProfile,
        hasSelectedAvatar: this.selectedAvatarUri.trim().length > 0,
        onNicknameChange: (value: string): void => {
          this.editNickname = value
        },
        onPickAvatar: (): void => {
          void this.handlePickAvatar()
        },
        onUploadAvatar: (): void => {
          void this.handleUploadAvatar()
        },
        onSaveProfile: (): void => {
          void this.handleSaveProfile()
        },
        onLogout: (): void => {
          void this.handleLogout()
        }
      })
    }
    .width('100%')
    .backgroundColor(PAGE_BG)
  }
}
