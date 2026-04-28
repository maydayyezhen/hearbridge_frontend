import { HttpClient } from '../common/http/HttpClient'
import { AppConfig } from '../common/constants/AppConfig'
import { AuthResponseDto, AuthUserDto, RecentPracticeDto } from '../model/ApiModels'

class LoginPayload {
  username: string = ''
  password: string = ''
}

class RegisterPayload {
  username: string = ''
  password: string = ''
  nickname: string = ''
}

class ProfilePayload {
  nickname: string = ''
}

class PasswordPayload {
  oldPassword: string = ''
  newPassword: string = ''
  confirmPassword: string = ''
}

class RecentPracticePayload {
  resourceId: number = 0
  resourceCode: string = ''
  chineseName: string = ''
  sigmlUrl: string = ''
  coverUrl: string = ''
}

export class AuthApi {
  static async login(username: string, password: string): Promise<AuthResponseDto> {
    const payload = new LoginPayload()
    payload.username = username
    payload.password = password
    const text = await HttpClient.post('/app/auth/login', payload)
    return AuthApi.parseAuthResponse(JSON.parse(text) as Record<string, Object>)
  }

  static async register(username: string, password: string, nickname: string): Promise<AuthResponseDto> {
    const payload = new RegisterPayload()
    payload.username = username
    payload.password = password
    payload.nickname = nickname
    const text = await HttpClient.post('/app/auth/register', payload)
    return AuthApi.parseAuthResponse(JSON.parse(text) as Record<string, Object>)
  }

  static async me(token: string): Promise<AuthUserDto> {
    const text = await HttpClient.get('/app/auth/me', token)
    return AuthApi.parseUser(JSON.parse(text) as Record<string, Object>)
  }

  static async updateProfile(token: string, nickname: string): Promise<AuthUserDto> {
    const payload = new ProfilePayload()
    payload.nickname = nickname
    const text = await HttpClient.put('/app/user/profile', payload, token)
    return AuthApi.parseUser(JSON.parse(text) as Record<string, Object>)
  }

  static async changePassword(token: string, oldPassword: string, newPassword: string, confirmPassword: string): Promise<void> {
    const payload = new PasswordPayload()
    payload.oldPassword = oldPassword
    payload.newPassword = newPassword
    payload.confirmPassword = confirmPassword
    await HttpClient.put('/app/user/password', payload, token)
  }

  static async uploadAvatar(token: string, fileName: string, mimeType: string, bytes: ArrayBuffer): Promise<AuthUserDto> {
    const text = await HttpClient.postBinary('/app/user/avatar', bytes, token, fileName, mimeType)
    return AuthApi.parseUser(JSON.parse(text) as Record<string, Object>)
  }

  /**
   * 获取当前用户最近练习。
   */
  static async getRecentPractice(): Promise<RecentPracticeDto> {
    const text = await HttpClient.get('/app/user/recent-practice')
    return AuthApi.parseRecentPractice(JSON.parse(text) as Record<string, Object>)
  }

  /**
   * 更新当前用户最近练习。
   */
  static async updateRecentPractice(practice: RecentPracticeDto): Promise<RecentPracticeDto> {
    const payload = new RecentPracticePayload()
    payload.resourceId = practice.resourceId
    payload.resourceCode = practice.resourceCode
    payload.chineseName = practice.chineseName
    payload.sigmlUrl = practice.sigmlUrl
    payload.coverUrl = practice.coverUrl

    const text = await HttpClient.put('/app/user/recent-practice', payload)
    return AuthApi.parseRecentPractice(JSON.parse(text) as Record<string, Object>)
  }

  static async logout(token: string): Promise<void> {
    await HttpClient.post('/app/auth/logout', undefined, token)
  }

  private static parseAuthResponse(source: Record<string, Object>): AuthResponseDto {
    const userSource = source['user'] as Record<string, Object>
    return new AuthResponseDto(
      AuthApi.readString(source, 'token'),
      AuthApi.parseUser(userSource)
    )
  }

  private static parseUser(source: Record<string, Object>): AuthUserDto {
    const avatarUrl = AppConfig.normalizeAssetUrl(AuthApi.readString(source, 'avatarUrl'), '')
    return new AuthUserDto(
      AuthApi.readNumber(source, 'id'),
      AuthApi.readString(source, 'username'),
      AuthApi.readString(source, 'nickname'),
      avatarUrl
    )
  }

  private static parseRecentPractice(source: Record<string, Object>): RecentPracticeDto {
    return new RecentPracticeDto(
      AuthApi.readNumber(source, 'resourceId'),
      AuthApi.readString(source, 'resourceCode'),
      AuthApi.readString(source, 'chineseName'),
      AuthApi.readString(source, 'sigmlUrl'),
      AuthApi.readString(source, 'coverUrl')
    )
  }

  private static readString(source: Record<string, Object>, key: string): string {
    const value = source[key]
    if (typeof value === 'string') {
      return value
    }
    if (typeof value === 'number' || typeof value === 'boolean') {
      return String(value)
    }
    return ''
  }

  private static readNumber(source: Record<string, Object>, key: string): number {
    const value = source[key]
    if (typeof value === 'number') {
      return Number.isFinite(value) ? value : 0
    }
    if (typeof value === 'string' && value.trim().length > 0) {
      const parsed = Number(value)
      return Number.isFinite(parsed) ? parsed : 0
    }
    return 0
  }
}
