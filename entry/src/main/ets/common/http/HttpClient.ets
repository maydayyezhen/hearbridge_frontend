import { http } from '@kit.NetworkKit'
import { AppConfig } from '../constants/AppConfig'
import { getStoredToken } from '../auth/AuthStorage'

export interface HttpClientRequestOptions {
  method?: http.RequestMethod
  body?: Object
  token?: string
}

export class HttpClient {
  static async get(path: string, token?: string): Promise<string> {
    return await HttpClient.request(path, {
      method: http.RequestMethod.GET,
      token: token
    })
  }

  static async post(path: string, body?: Object, token?: string): Promise<string> {
    return await HttpClient.request(path, {
      method: http.RequestMethod.POST,
      body: body,
      token: token
    })
  }

  static async put(path: string, body?: Object, token?: string): Promise<string> {
    return await HttpClient.request(path, {
      method: http.RequestMethod.PUT,
      body: body,
      token: token
    })
  }

  static async postBinary(path: string, bytes: ArrayBuffer, token: string, fileName: string, contentType: string): Promise<string> {
    let httpRequest = http.createHttp()
    try {
      const requestToken = HttpClient.resolveToken(token)
      const headers: Record<string, string> = {
        'Content-Type': contentType,
        'X-Filename': encodeURIComponent(fileName)
      }
      HttpClient.attachAuthHeaders(headers, requestToken)

      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: http.RequestMethod.POST,
          header: headers,
          extraData: bytes,
          connectTimeout: 10000,
          readTimeout: 30000
        }
      )

      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(responseText.length > 0 ? responseText : `请求失败，状态码：${response.responseCode}`)
      }
      return responseText
    } finally {
      httpRequest.destroy()
    }
  }

  static async request(path: string, options: HttpClientRequestOptions): Promise<string> {
    let httpRequest = http.createHttp()
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    }
    const requestToken = HttpClient.resolveToken(options.token)
    HttpClient.attachAuthHeaders(headers, requestToken)

    try {
      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: options.method ?? http.RequestMethod.GET,
          header: headers,
          extraData: options.body ? JSON.stringify(options.body) : '',
          connectTimeout: 10000,
          readTimeout: 10000
        }
      )

      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(responseText.length > 0 ? responseText : `请求失败，状态码：${response.responseCode}`)
      }

      return responseText
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * 解析请求 token。
   *
   * 说明：
   * 1. 调用方显式传 token 时优先使用调用方传入值。
   * 2. 调用方未传 token 时，从 AppStorage 登录态中自动读取。
   * 3. 没有 token 时返回空字符串，请求层不会额外携带鉴权头。
   */
  private static resolveToken(explicitToken?: string): string {
    if (explicitToken && explicitToken.trim().length > 0) {
      return explicitToken.trim()
    }
    return getStoredToken().trim()
  }

  /**
   * 自动追加鉴权请求头。
   *
   * 说明：
   * 1. Authorization 用于后端管理端拦截器 Bearer token 规范。
   * 2. token 头用于兼容手机端旧接口读取方式。
   */
  private static attachAuthHeaders(headers: Record<string, string>, token: string): void {
    if (token.length === 0) {
      return
    }
    headers['Authorization'] = `Bearer ${token}`
    headers['token'] = token
  }
}
