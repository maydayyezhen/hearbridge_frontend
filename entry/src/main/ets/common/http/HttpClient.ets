import { http } from '@kit.NetworkKit'
import { AppConfig } from '../constants/AppConfig'

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
      const response = await httpRequest.request(
        `${AppConfig.BASE_URL}${path}`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': contentType,
            'token': token,
            'X-Filename': encodeURIComponent(fileName)
          },
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

    if (options.token && options.token.trim().length > 0) {
      headers['token'] = options.token.trim()
    }

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
}
