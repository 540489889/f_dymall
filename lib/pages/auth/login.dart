/// 登录模板
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../utils/index.dart';
import '../../controller/auth_store.dart';

class Login extends StatefulWidget {
  const Login({super.key});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final authStore = AuthStore.to;

  final Map authObj = {
  'tel': '',
  'pwd': '',
  'isVisiblePwd': true
};

final fieldController = TextEditingController();

@override
void initState() {
  super.initState();
}

// 清空文本框
void handleClear() {
  fieldController.clear();
  setState(() {
    authObj['tel'] = '';
  });
}

void handleSubmit() async {
  if(authObj['tel'] == '') {
    MyDialog.toast('请输入手机号', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(!Utils.checkTel(authObj['tel'])) {
    MyDialog.toast('手机号格式不正确', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(authObj['pwd'] == '') {
    MyDialog.toast('请输入密码', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else {
    // 存储登录信息
    authStore.setAuthorization(Utils.uuid());

    MyDialog.toast('登录成功', icon: Icon(Icons.check_circle_rounded), style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)));
    Timer(Duration(seconds: 2), () {
        Get.offAllNamed('/');
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
      forceMaterialTransparency: true,
      toolbarHeight: 0,
    ),
    body: GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(top: 50.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30.0),
              child: Column(
                children: [
                Image.asset('assets/images/logo.png',height: 75.0,width: 75.0,fit: BoxFit.cover),
                const SizedBox(height: 5.0,),
                const Text('flutter3-dymall', style: TextStyle(color: Color(0xFFFF2C55), fontSize: 25.0,)),
              ],
              ),
            ),
            Container(
              height: 40.0,
              margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 30.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Row(
                children: [
                  Expanded(
                  child: TextField(
                    keyboardType: TextInputType.phone,
                    controller: fieldController,
                  decoration: InputDecoration(
                    hintText: '输入手机号',
                  hintStyle: const TextStyle(color: Colors.black38),
                  suffixIcon: Visibility(
                    visible: authObj['tel'].isNotEmpty,
                      child: InkWell(
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        onTap: handleClear,
                        child: const Icon(Icons.clear, color: Colors.grey, size: 16.0,),
                      )
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12.0),
                    border: const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  onChanged: (value) {
                    setState(() {
                      authObj['tel'] = value;
                      });
                      },
                    ),
                    )
                  ],
                ),
              ),
              Container(
                height: 40.0,
                margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 30.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(30.0),
              ),
              child: Row(
                children: [
                Expanded(
                  child: TextField(
                  decoration: InputDecoration(
                    hintText: '输入密码',
                    hintStyle: const TextStyle(color: Colors.black38),
                  suffixIcon: InkWell(
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    child: Icon(authObj['isVisiblePwd'] ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 16.0),
                    onTap: () {
                      setState(() {
                        authObj['isVisiblePwd'] = !authObj['isVisiblePwd'];
                      });
                    },
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12.0),
                    border: const OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                  obscureText: authObj['isVisiblePwd'],
                  onChanged: (value) {
                    setState(() {
                      authObj['pwd'] = value;
                    });
                  },
                  ),
                  )
                ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30.0),
                // 自定义按钮渐变色
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF2C55), Color(0xFFFF9C55)
                  ],
                )
              ),
              child: SizedBox(
              width: double.infinity,
              height: 45.0,
            child: FilledButton(
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(Colors.transparent),
                shadowColor: WidgetStateProperty.all(Colors.transparent),
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                handleSubmit();
              },
              child: const Text('登录', style: TextStyle(fontSize: 16.0),),
            ),
            )
          ),
          const SizedBox(height: 10.0,),
          IntrinsicHeight(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(child: const Text('忘记密码', style: TextStyle(color: Colors.grey, fontSize: 14.0)), onTap: () {}),
                // 需要使用IntrinsicHeight组件包裹，否则分割线不显示
                const VerticalDivider(color: Colors.black38, width: 30.0, indent: 5.0, endIndent: 2.0, thickness: .5,),
                InkWell(child: const Text('注册账号', style: TextStyle(color: Colors.grey, fontSize: 14.0)), onTap: () {Navigator.pushNamed(context, '/register');}),
              ]
            ),
            )
          ],
        ),
        ),
      ),
    );
  }
}
