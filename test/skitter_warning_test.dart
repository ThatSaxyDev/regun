import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:regun/presentation/attack_vfx.dart';
import 'package:regun/presentation/regun_art.dart';
import 'package:regun/presentation/boss_art.dart';
import 'package:regun/data/loadout.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Skitter warning remains readable from commitment on both arena floors',()async{
  await RegunArt.shared.load();
  final recorder=ui.PictureRecorder(),c=Canvas(recorder);
  for(var row=0;row<2;row++){
   final bg=row==0?const Color(0xff29292b):const Color(0xff42332c);
   c.drawRect(Rect.fromLTWH(0,row*180.0,640,180),Paint()..color=bg);
   for(var stage=0;stage<2;stage++){
    c.save();c.translate(20,row*180.0+45+stage*75);
    AttackVfx.lungeWarning(c,Offset.zero,const Offset(500,0),progress:stage*.9,
      ambient:BossArt.ambient(row==0?ArenaType.breach:ArenaType.foundry));c.restore();
   }
  }
  final picture=recorder.endRecording(),im=await picture.toImage(640,360);
  final bytes=(await im.toByteData(format:ui.ImageByteFormat.rawRgba))!;
  // Contrast must be present immediately, not only at the end of the warning.
  for(final y in [45,225]){
   var bright=0;
   for(var yy=y-28;yy<y+28;yy++){ for(var x=30;x<510;x++){
    final i=(yy*640+x)*4;
    if(bytes.getUint8(i)>115 && bytes.getUint8(i+1)>105)bright++;
   }
   }
   // The new narrow scuffs deliberately occupy fewer pixels than the old claws.
   expect(bright,greaterThan(200));
   expect(bright,lessThan(2400));
  }
  await Directory('build/test-previews').create(recursive:true);
  final png=(await im.toByteData(format:ui.ImageByteFormat.png))!;
  await File('build/test-previews/skitter-warning.png').writeAsBytes(png.buffer.asUint8List());
  im.dispose();picture.dispose();
 });
}
