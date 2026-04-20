import { http } from '@kit.NetworkKit'
import { AppConfig } from '../constants/AppConfig'

/**
 * HTTP 客户端
 */
export class HttpClient {
  /**
   * 发起 GET 请求
   */
  static async get(path: string): Promise<string> {
    let httpRequest = http.createHttp()

    try {
      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Content-Type': 'application/json'
          },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      )

      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`请求失败，状态码：${response.responseCode}`)
      }

      return response.result.toString()
    } finally {
      httpRequest.destroy()
    }
  }
}