import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import { AuthUserDto } from '../../model/ApiModels'

const STORE_NAME: string = 'hearbridge_auth'
const TOKEN_KEY: string = 'token'
const USER_ID_KEY: string = 'userId'
const USERNAME_KEY: string = 'username'
const NICKNAME_KEY: string = 'nickname'
const AVATAR_URL_KEY: string = 'avatarUrl'

export function initAuthState(): void {
  AppStorage.setOrCreate('auth.token', '')
  AppStorage.setOrCreate('auth.isLoggedIn', false)
  AppStorage.setOrCreate('auth.user.id', 0)
  AppStorage.setOrCreate('auth.user.username', '')
  AppStorage.setOrCreate('auth.user.nickname', '')
  AppStorage.setOrCreate('auth.user.avatarUrl', '')
}

export function getStoredToken(): string {
  return (AppStorage.get('auth.token') as string | undefined) ?? ''
}

export function getStoredUser(): AuthUserDto {
  return new AuthUserDto(
    (AppStorage.get('auth.user.id') as number | undefined) ?? 0,
    (AppStorage.get('auth.user.username') as string | undefined) ?? '',
    (AppStorage.get('auth.user.nickname') as string | undefined) ?? '',
    (AppStorage.get('auth.user.avatarUrl') as string | undefined) ?? ''
  )
}

export async function restoreAuthState(context: common.BaseContext): Promise<void> {
  initAuthState()
  try {
    const store = await preferences.getPreferences(context, STORE_NAME)
    const token = await store.get(TOKEN_KEY, '')
    const userId = await store.get(USER_ID_KEY, 0)
    const username = await store.get(USERNAME_KEY, '')
    const nickname = await store.get(NICKNAME_KEY, '')
    const avatarUrl = await store.get(AVATAR_URL_KEY, '')

    const tokenText = typeof token === 'string' ? token : ''
    AppStorage.setOrCreate('auth.token', tokenText)
    AppStorage.setOrCreate('auth.isLoggedIn', tokenText.length > 0)
    AppStorage.setOrCreate('auth.user.id', Number(userId ?? 0))
    AppStorage.setOrCreate('auth.user.username', typeof username === 'string' ? username : '')
    AppStorage.setOrCreate('auth.user.nickname', typeof nickname === 'string' ? nickname : '')
    AppStorage.setOrCreate('auth.user.avatarUrl', typeof avatarUrl === 'string' ? avatarUrl : '')
  } catch (_error) {
    initAuthState()
  }
}

export async function saveAuthState(context: common.BaseContext, token: string, user: AuthUserDto): Promise<void> {
  applyAuthState(token, user)
  try {
    const store = await preferences.getPreferences(context, STORE_NAME)
    await store.put(TOKEN_KEY, token)
    await store.put(USER_ID_KEY, user.id)
    await store.put(USERNAME_KEY, user.username)
    await store.put(NICKNAME_KEY, user.nickname)
    await store.put(AVATAR_URL_KEY, user.avatarUrl)
    await store.flush()
  } catch (_error) {
    return
  }
}

export async function saveUserState(context: common.BaseContext, user: AuthUserDto): Promise<void> {
  const token = getStoredToken()
  await saveAuthState(context, token, user)
}

export async function clearAuthState(context: common.BaseContext): Promise<void> {
  applyAuthState('', new AuthUserDto(0, '', '', ''))
  try {
    const store = await preferences.getPreferences(context, STORE_NAME)
    await store.clear()
    await store.flush()
  } catch (_error) {
    return
  }
}

function applyAuthState(token: string, user: AuthUserDto): void {
  AppStorage.setOrCreate('auth.token', token)
  AppStorage.setOrCreate('auth.isLoggedIn', token.length > 0)
  AppStorage.setOrCreate('auth.user.id', user.id)
  AppStorage.setOrCreate('auth.user.username', user.username)
  AppStorage.setOrCreate('auth.user.nickname', user.nickname)
  AppStorage.setOrCreate('auth.user.avatarUrl', user.avatarUrl)
}
