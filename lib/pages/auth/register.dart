/// 注册模板
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shirne_dialog/shirne_dialog.dart';
import '../../utils/index.dart';
import '../../controller/auth_store.dart';

class Register extends StatefulWidget {
  const Register({super.key});
  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final authStore = AuthStore.to;

  final Map authObj = {
  'tel': '',
  'pwd': '',
  'isVisiblePwd': true,
  'vcode': ''
};

final fieldController = TextEditingController();
Timer? timer;
String vcodeText = '获取验证码';
bool disabled = false;
int time = 60;

@override
void initState() {
  super.initState();
}

@override
void dispose() {
  super.dispose();
  timer?.cancel();
}

// 清空文本框
void handleClear() {
  fieldController.clear();
  setState(() {
    authObj['tel'] = '';
    });
  }

  // 提交表单
  void handleSubmit() async {
    if(authObj['tel'] == '') {
    MyDialog.toast('手机号不能为空', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(!Utils.checkTel(authObj['tel'])) {
    MyDialog.toast('手机号格式不正确', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(authObj['pwd'] == '') {
    MyDialog.toast('密码不能为空', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(authObj['vcode'] == '') {
    MyDialog.toast('验证码不能为空', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else {
    // 存储登录信息
    authStore.setAuthorization(Utils.uuid());

    MyDialog.toast('恭喜，注册成功', icon: Icon(Icons.check_circle_rounded), style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)));
    Timer(const Duration(seconds: 2), () {
      Get.offAllNamed('/');
    });
  }
}

// 60s倒计时
void handleVcode() {
  if(authObj['tel'] == '') {
    MyDialog.toast('手机号不能为空', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else if(!Utils.checkTel(authObj['tel'])) {
    MyDialog.toast('手机号格式不正确', icon: Icon(Icons.warning_rounded), style: ToastStyle(backgroundColor: Colors.red.withAlpha(200)));
  }else {
    setState(() {
      disabled = true;
    });
    startTimer();
    }
  }
  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    setState(() {
      if(time > 0) {
        vcodeText = '获取验证码(${time--})';
      }else {
        vcodeText = '获取验证码';
        time = 60;
        disabled = false;
        timer.cancel();
      }
    });
  });
  MyDialog.toast('验证码已发送，请注意查收', style: ToastStyle(backgroundColor: Colors.green.withAlpha(200)));
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
              decoration: const InputDecoration(
                hintText: '验证码',
              hintStyle: TextStyle(color: Colors.black38),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12.0),
              border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                setState(() {
                  authObj['vcode'] = value;
                  });
                  },
                ),
              ),
              SizedBox(
                height: 25.0,
              child: Container(
              margin: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0))
                  ),
                  padding: WidgetStateProperty.all(EdgeInsets.symmetric(horizontal: 15.0))
                ),
                onPressed: !disabled ? handleVcode : null,
                child: Text(vcodeText, style: const TextStyle(fontSize: 13.0)),
              ),
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
                Color(0xFFFF2C8F), Color(0xFFFFBA31)
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
            child: const Text('注册', style: TextStyle(fontSize: 16.0),),
            ),
          )
          ),
          const SizedBox(height: 10.0,),
          IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(child: const Text('已有账号，去登录', style: TextStyle(color: Colors.grey, fontSize: 14.0)), onTap: () {Navigator.pushNamed(context, '/login');}),
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
