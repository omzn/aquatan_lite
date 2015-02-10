Aquatan Lite
==============

このプログラムは水槽監視ロボット「あくあたん」の簡易版です．

できること
---------

* Raspberry Piを使ってモーターの駆動ができる．
* モーターの駆動をスイッチとフォトリフレクタで制御できる．
* ツイッターアカウントを通じてメンションでモーターを駆動させることができる．
* ついでにUSBカメラで写真も撮れる．

インストール
---------

src 下で以下の手順を実行
```
$ make; make install
```

./setup.sh を実行
```
$ setup.sh
```

ppitでツイッターのアクセス情報を設定する
```
$ export EDITOR=vi
$ ppit set aqua
--- {
comsumer_key: 自身のcomsumer_key,
comsumer_secret: 自身のcomsumer_secret,
access_token: 自身のaccess_token,
access_token_secret: 自身のaccess_token_secret
}
```

実行
------
bin 下で，次のプログラムを実行
```
$ ./bot_aquatan_lite.pl
```

ツイッターから，botに向けてmentionを送る．
```
@your_bot 写真撮影
@your_bot 左に移動
```
