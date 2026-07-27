import { NativeModules, Platform } from 'react-native';

export type SATagProvider =
  | 'AppsFlyer'
  | 'Facebook'
  | 'TikTok'
  | 'Firebase';

export type SATagInitializationState =
  | 'initialized'
  | 'missingConfiguration'
  | 'notIntegrated'
  | 'failed'
  | 'alreadyInitialized';

export type SATagEventState =
  | 'accepted'
  | 'notInitialized'
  | 'notIntegrated'
  | 'failed'
  | 'invalidEvent';

export interface SATagInitializeOptions {
  appsFlyerDevKey: string;
  appleAppID: string;
}

export interface SATagInitializationResult {
  provider: number;
  providerName: SATagProvider | string;
  state: SATagInitializationState | string;
  stateCode: number;
  reason: string;
  configurationSummary: Record<string, string>;
  timestamp: number;
}

export interface SATagEventResult {
  provider: number;
  providerName: SATagProvider | string;
  state: SATagEventState | string;
  stateCode: number;
  eventName: string;
  reason: string;
  timestamp: number;
}

interface SATagExpoNativeModule {
  initialize(options: SATagInitializeOptions): Promise<SATagInitializationResult[]>;
  track(
    eventName: string,
    parameters: Record<string, unknown>,
  ): Promise<SATagEventResult[]>;
  trackAppsFlyer(
    eventName: string,
    parameters: Record<string, unknown>,
  ): Promise<SATagEventResult>;
  trackFacebook(
    eventName: string,
    parameters: Record<string, unknown>,
  ): Promise<SATagEventResult>;
  trackTikTok(
    eventName: string,
    parameters: Record<string, unknown>,
  ): Promise<SATagEventResult>;
  trackFirebase(
    eventName: string,
    parameters: Record<string, unknown>,
  ): Promise<SATagEventResult>;
  presentDebugView(): Promise<void>;
}

function nativeModule(): SATagExpoNativeModule {
  if (Platform.OS !== 'ios') {
    throw new Error('SATagSDK Expo 当前只支持 iOS，Android 尚未提供原生 Provider。');
  }

  const module = NativeModules.SATagExpoModule as SATagExpoNativeModule | undefined;
  if (!module) {
    throw new Error(
      '未找到 SATagExpoModule。请执行 npx expo prebuild，并使用 Expo development build 或 EAS Build。',
    );
  }
  return module;
}

export function initialize(
  options: SATagInitializeOptions,
): Promise<SATagInitializationResult[]> {
  return nativeModule().initialize(options);
}

export function track(
  eventName: string,
  parameters: Record<string, unknown> = {},
): Promise<SATagEventResult[]> {
  return nativeModule().track(eventName, parameters);
}

export function trackAppsFlyer(
  eventName: string,
  parameters: Record<string, unknown> = {},
): Promise<SATagEventResult> {
  return nativeModule().trackAppsFlyer(eventName, parameters);
}

export function trackFacebook(
  eventName: string,
  parameters: Record<string, unknown> = {},
): Promise<SATagEventResult> {
  return nativeModule().trackFacebook(eventName, parameters);
}

export function trackTikTok(
  eventName: string,
  parameters: Record<string, unknown> = {},
): Promise<SATagEventResult> {
  return nativeModule().trackTikTok(eventName, parameters);
}

export function trackFirebase(
  eventName: string,
  parameters: Record<string, unknown> = {},
): Promise<SATagEventResult> {
  return nativeModule().trackFirebase(eventName, parameters);
}

export function presentDebugView(): Promise<void> {
  return nativeModule().presentDebugView();
}

export default {
  initialize,
  track,
  trackAppsFlyer,
  trackFacebook,
  trackTikTok,
  trackFirebase,
  presentDebugView,
};
