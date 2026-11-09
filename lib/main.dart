import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const QuranPrayerApp());
const bg = Color(0xFF071713), panel = Color(0xCC12352B), emerald = Color(0xFF20B486), gold = Color(0xFFE4C477);

class QuranPrayerApp extends StatelessWidget {
  const QuranPrayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'نور القرآن',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald, brightness: Brightness.dark), useMaterial3: true),
    home: const MainShell());
}
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int tab = 0;
  final pages = const [QuranPage(), PrayerPage(), SettingsPage()];
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20,18,20,12), child: Row(children: [
        Container(width:44,height:44,decoration:BoxDecoration(color:emerald.withOpacity(.16),borderRadius:BorderRadius.circular(15),border:Border.all(color:gold.withOpacity(.45))),child:const Icon(Icons.auto_stories_rounded,color:gold)),
        const SizedBox(width:12), const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('نور القرآن',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),
          Text('القرآن الكريم ومواقيت الصلاة',style:TextStyle(color:Colors.white60,fontSize:12))])),
        const Icon(Icons.nights_stay_rounded,color:gold)])),
      Expanded(child:IndexedStack(index:tab,children:pages))])),
    bottomNavigationBar:NavigationBar(backgroundColor:const Color(0xFF0D241D),indicatorColor:emerald.withOpacity(.22),selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.menu_book_outlined),selectedIcon:Icon(Icons.menu_book),label:'القرآن'),
      NavigationDestination(icon:Icon(Icons.mosque_outlined),selectedIcon:Icon(Icons.mosque),label:'الصلاة'),
      NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'الإعدادات')]))); 
}
Widget glassCard({required Widget child, EdgeInsets padding=const EdgeInsets.all(18)})=>Container(width:double.infinity,padding:padding,decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(22),border:Border.all(color:Colors.white.withOpacity(.09)),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.18),blurRadius:18,offset:const Offset(0,8))]),child:child);

class QuranPage extends StatefulWidget { const QuranPage({super.key}); @override State<QuranPage> createState()=>_QuranPageState(); }
class _QuranPageState extends State<QuranPage>{
  List<dynamic> surahs=[]; bool loading=true; String? error;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    setState(()=>loading=true);
    try{final r=await http.get(Uri.parse('https://api.alquran.cloud/v1/surah')).timeout(const Duration(seconds:15));if(r.statusCode!=200)throw Exception();surahs=jsonDecode(r.body)['data'] as List;error=null;}
    catch(_){error='تعذر الاتصال. تحقق من الإنترنت ثم أعد المحاولة.';}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(18,8,18,24),children:[
    glassCard(child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا',style:TextStyle(fontSize:23,color:gold,fontWeight:FontWeight.bold)),
      SizedBox(height:8),Text('ابدأ رحلتك مع آيات الله',style:TextStyle(color:Colors.white70)),
      SizedBox(height:14),Row(children:[Icon(Icons.bookmark_added_outlined,color:emerald),SizedBox(width:8),Text('القرآن الكريم')])])),
    const SizedBox(height:18),const Text('سور القرآن الكريم',style:TextStyle(fontSize:19,fontWeight:FontWeight.bold)),const SizedBox(height:10),
    if(loading)const Center(child:Padding(padding:EdgeInsets.all(30),child:CircularProgressIndicator(color:gold))),
    if(error!=null)glassCard(child:Column(children:[Text(error!,textAlign:TextAlign.center),TextButton.icon(onPressed:load,icon:const Icon(Icons.refresh),label:const Text('إعادة المحاولة'))])),
    ...surahs.map((s)=>Padding(padding:const EdgeInsets.only(bottom:8),child:glassCard(padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),child:Row(children:[
      Container(width:38,height:38,alignment:Alignment.center,decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:gold.withOpacity(.5))),child:Text(s['number'].toString(),style:const TextStyle(color:gold))),
      const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(s['name'].toString(),style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
        Text(s['englishName'].toString()+' • '+s['numberOfAyahs'].toString()+' آية',style:const TextStyle(color:Colors.white54,fontSize:11))])),
      const Icon(Icons.chevron_left,color:gold)]))))]);
}

class PrayerPage extends StatefulWidget { const PrayerPage({super.key}); @override State<PrayerPage> createState()=>_PrayerPageState(); }
class _PrayerPageState extends State<PrayerPage>{
  bool jaafari=true,loading=false; String city='Baghdad'; Map<String,dynamic>? times; String? error;
  final names={'Fajr':'الفجر','Sunrise':'الشروق','Dhuhr':'الظهر','Asr':'العصر','Maghrib':'المغرب','Isha':'العشاء'};
  final cityController=TextEditingController(text:'Baghdad');
  @override void initState(){super.initState();fetch();}
  Future<void> fetch() async{
    setState(()=>loading=true);
    try{final url=Uri.https('api.aladhan.com','/v1/timingsByCity',{'city':city,'country':'Iraq','method':jaafari?'0':'3'});
      final r=await http.get(url).timeout(const Duration(seconds:15));final data=jsonDecode(r.body);
      if(r.statusCode!=200||data['code']!=200)throw Exception();times=data['data']['timings'];error=null;
    }catch(_){error='تعذر جلب المواقيت. تحقق من الإنترنت واسم المدينة.';}
    if(mounted)setState(()=>loading=false);
  }
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(18,8,18,24),children:[
    glassCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('مواقيت الصلاة',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
      Text(city,style:const TextStyle(color:gold)),const SizedBox(height:12),
      SegmentedButton<bool>(segments:const[ButtonSegment(value:true,label:Text('جعفري')),ButtonSegment(value:false,label:Text('سني'))],selected:{jaafari},onSelectionChanged:(v){setState(()=>jaafari=v.first);fetch();}),
      const SizedBox(height:10),Row(children:[Expanded(child:TextField(controller:cityController,decoration:const InputDecoration(labelText:'المدينة'),onSubmitted:(v){city=v.trim().isEmpty?'Baghdad':v.trim();fetch();})),IconButton(onPressed:(){city=cityController.text.trim();fetch();},icon:const Icon(Icons.refresh,color:gold))])
    ])),
    const SizedBox(height:14),if(loading)const Center(child:CircularProgressIndicator(color:gold)),
    if(error!=null)glassCard(child:Text(error!,textAlign:TextAlign.center)),
    if(times!=null)...names.entries.map((e)=>Padding(padding:const EdgeInsets.only(bottom:8),child:glassCard(padding:const EdgeInsets.symmetric(horizontal:18,vertical:15),child:Row(children:[
      const Icon(Icons.access_time,color:emerald),const SizedBox(width:12),Expanded(child:Text(e.value,style:const TextStyle(fontSize:17))),
      Text(times![e.key]?.toString()??'--:--',style:const TextStyle(color:gold,fontSize:18,fontWeight:FontWeight.bold))])))),
    const Text('المواقيت تُجلب عبر خدمة الحساب الفلكي حسب المدينة وطريقة الحساب المختارة. قد تختلف التفاصيل باختلاف المرجع المحلي.',style:TextStyle(color:Colors.white54,fontSize:11))
  ]);
}
class SettingsPage extends StatelessWidget{
  const SettingsPage({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(18),children:[
    glassCard(child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الإعدادات',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),SizedBox(height:8),Text('خصص تجربة القراءة ومواقيت الصلاة.',style:TextStyle(color:Colors.white60))])),
    const SizedBox(height:12),glassCard(child:const Column(children:[
      ListTile(leading:Icon(Icons.notifications_active_outlined,color:gold),title:Text('تنبيهات الصلاة'),subtitle:Text('تنبيهات الأذان قيد التطوير ولم تُفعّل بعد.')),
      Divider(color:Colors.white12),ListTile(leading:Icon(Icons.record_voice_over_outlined,color:gold),title:Text('القارئ والمؤذن'),subtitle:Text('اختيار الأصوات قيد التجهيز.')),
      Divider(color:Colors.white12),ListTile(leading:Icon(Icons.info_outline,color:gold),title:Text('حول التطبيق'),subtitle:Text('نور القرآن • الإصدار 1.0.0'))]))]);
}
