import React, { useRef, useState, useCallback } from 'react';
import { View, Text, SafeAreaView, Platform, Linking, RefreshControl } from 'react-native';
import { WebView } from 'react-native-webview';

// عنوان موقعك:
const START_URL = 'https://farfish.pythonanywhere.com/';

export default function App() {
  const wvRef = useRef(null);
  const [canGoBack, setCanGoBack] = useState(false);
  const [canGoForward, setCanGoForward] = useState(false);
  const [loading, setLoading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [refreshing, setRefreshing] = useState(false);

  // فتح الروابط الخارجية في التطبيقات المناسبة / سفاري
  const handleExternal = useCallback(async (url) => {
    try { await Linking.openURL(url); } catch (e) { console.warn('openURL failed', e); }
  }, []);

  // فلترة الروابط: أبقِ pythonanywhere داخل الويب فيو، وافتح غيره خارجيًا
  const shouldStart = useCallback((req) => {
    const url = req.url || '';
    const host = (() => {
      try { return new URL(url).host.toLowerCase(); } catch { return ''; }
    })();
    const scheme = (() => {
      try { return new URL(url).protocol.replace(':','').toLowerCase(); } catch { return ''; }
    })();

    const extSchemes = ['tel','mailto','sms','whatsapp','geo','maps'];
    if (extSchemes.includes(scheme) || url.includes('wa.me') ) {
      handleExternal(url);
      return false;
    }
    if (!host.includes('pythonanywhere.com')) {
      // روابط خارج الموقع → افتحها في سفاري/التطبيق المناسب
      handleExternal(url);
      return false;
    }
    return true;
  }, [handleExternal]);

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    wvRef.current?.reload();
    setTimeout(() => setRefreshing(false), 800);
  }, []);

  return (
    <SafeAreaView style={{flex:1, backgroundColor:'#fff'}}>
      {/* شريط تقدم نحيف */}
      <View style={{height: loading ? 2 : 0, backgroundColor:'#0aa79d', width: `${Math.max(progress*100, 4)}%`}} />

      <WebView
        ref={wvRef}
        source={{ uri: START_URL }}
        onLoadStart={() => setLoading(true)}
        onLoadEnd={() => setLoading(false)}
        onLoadProgress={({ nativeEvent }) => setProgress(nativeEvent.progress)}
        onNavigationStateChange={(nav) => {
          setCanGoBack(nav.canGoBack);
          setCanGoForward(nav.canGoForward);
        }}
        originWhitelist={['*']}
        setSupportMultipleWindows={true}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        allowsInlineMediaPlayback={true}
        mediaPlaybackRequiresUserAction={false}
        startInLoadingState={false}
        // iOS/Android: تحكم ببداية التنقل
        onShouldStartLoadWithRequest={shouldStart}
        // سحب للتحديث (iOS فقط افتراضيًا)
        pullToRefreshEnabled={Platform.OS === 'ios'}
        // أندرويد: سحب للتحديث عبر RefreshControl
        overScrollMode="always"
        bounces={true}
        nestedScrollEnabled={true}
        refreshControl={
          Platform.OS === 'android'
            ? <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
            : undefined
        }
        // تفعيل الويب جيولوكيشن داخل الويب فيو يتطلب صلاحيات Info.plist على iOS
        geolocationEnabled={true}
        // رفع الملفات مدعوم تلقائيًا؛ إن واجهت مشكلة سنتعامل معها بتهيئة إضافية
      />

      {/* شريط أزرار بسيط أسفل الشاشة */}
      <View style={{
        position:'absolute', bottom:10, left:10, right:10,
        backgroundColor:'#ffffffea', borderRadius:12, flexDirection:'row',
        justifyContent:'space-between', padding:10, shadowColor:'#000', shadowOpacity:0.08,
        shadowRadius:6, shadowOffset:{width:0,height:4}, elevation:2
      }}>
        <Text
          onPress={()=> wvRef.current?.goBack()}
          style={{fontWeight:'700', color: canGoBack ? '#0aa79d' : '#8fa3aa'}}
        >رجوع</Text>
        <Text onPress={()=> wvRef.current?.reload()} style={{fontWeight:'700', color:'#0aa79d'}}>تحديث</Text>
        <Text
          onPress={()=> wvRef.current?.goForward()}
          style={{fontWeight:'700', color: canGoForward ? '#0aa79d' : '#8fa3aa'}}
        >تقدم</Text>
      </View>
    </SafeAreaView>
  );
}
