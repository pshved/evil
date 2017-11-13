= How to participate in the development

== Using a virtual machine

To participate in Evil development, the easiest way is to download "development virtual machine":http://static.coldattic.info/r/evil/zlo_dev.ova (1 Gb) in "OVF format":http://en.wikipedia.org/wiki/Open_Virtualization_Format.  The format is supported by virtualbox.

It's Ubuntu Server instance with a dump of x.coldattic.info database deployed; the sources are as of commit:5d28ed2c.  To run the server, log in as user @zlowik@, password @12345@, then execute @./run_evil.sh@.  Do not forget to forward port 3000, at which the board is run, to the outside world.  By default it's forwarded as 4000.  So, just open "@localhost:4000@" in your browser, and you should see the index page.

The sources are in the @evil/@ folder.  You may edit them with vim or mcedit, whichever is your favorite.

== Running in development mode

Рабочее окружение будет создано аким образом, что будет находиться целиком в пользовательской папке, и не повлияет на системное.  Для этого будет использован RVM, менеджер инсталляций руби, который позволяет готовить окружения для руби-приложений, включающие в себя сам интерпретатор и гемы, не засирая систему.  Сначала скачиваем и ставим "RVM":http://beginrescueend.com/.  В консоли делаем @source ~/.bash_profile@, как того предлагает инсталлятор, если нужно.  Затем ставим такую же версию руби, как и на сервере:

  rvm install ruby-1.9.3-p125 -C --enable-shared

(Версия 125 нужна, чтобы установился дебаггер.  В мае 2012 он ещё не был пропатчен до последней версии). Затем, нужно установить установщик гемов, а затем через него установить сами гемы, записанные в приложении.  Ручками ничего делать не надо, просто запустить две команды:

  rvm ruby-1.9.3 do gem install bundler
  rvm ruby-1.9.3 do bundle install

Ошибки, возникающие при выполнении последней команды, надо лечить установкой девел-пакетов для системных библиотек через средства вашего Линукса.  Например, придётся поставить mysql-dev. 

== База данных

К сожалению, я сделал так, чтобы борда не работала с SQLite.  Поэтому вам понадобится MySQL.  Прежде, чем создавать базу (да, *перед, а не после*), добавьте в @/etc/my.cnf@ или аналог настройки, ставящие юникод по умолчанию:

  [mysqld]
  default-character-set=utf8
  default-collation=utf8_general_ci

Не забудьте перезапустить MySQL (@/etc/init.d/mysql restart@).

Cоздайте базу данных MySQL (если есть желание, с пользователями и паролем):

  $ mysql -uroot -ppassword
  mysql> create database evil;
  mysql> create user zlowik;
  mysql> grant all on evil.* to zlowik@localhost;
  mysql> flush privileges;

Вставьте дамп базы, сделанный с помощью mysqldump и запакованный гзипом:

  zcat dump.sql.gz | mysql -uzlowik evil

Затем создайте конфигурационный файл @config/database.yml@

	development:
		adapter: mysql2
		encoding: utf8
		reconnect: false
		database: evil
		pool: 5
		username: zlowik
		password:
		socket: /var/lib/mysql/mysql.sock

	production:
    (то же самое для продакшн базы)

=== Запуск приложения

Если всё сделано правильно, то на этом этапе должно запуститься

   rvm ruby-1.9.3 do rails server

Когда появится строчка "INFO  WEBrick::HTTPServer#start: pid=26214 port=3000", зайдите в браузере на localhost:3000


== Running in production mode

After you have configured the development mode, you need to make several additional actions to run in production.
