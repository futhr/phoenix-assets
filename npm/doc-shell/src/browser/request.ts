import { isAllowedTryItOrigin, resolveTryItTarget } from "../url.js"

export interface RequestPolicy {
  apiOrigin: string
  allowedOrigins?: readonly string[]
  currentHref?: string
}

export interface AdmittedRequest {
  url: string
  crossOrigin: boolean
  confirmation: string | undefined
  credentials: RequestCredentials
}

export const admitRequest = (operationPath: string, policy: RequestPolicy): AdmittedRequest => {
  const target = resolveTryItTarget(policy.apiOrigin, operationPath, policy.currentHref)
  if (target.crossOrigin && !isAllowedTryItOrigin(target.origin, policy.allowedOrigins ?? [])) {
    throw new Error("request origin is not allowlisted")
  }
  return {
    url: target.url,
    crossOrigin: target.crossOrigin,
    confirmation: target.crossOrigin ? `Send this request to ${target.origin}` : undefined,
    credentials: "same-origin",
  }
}
