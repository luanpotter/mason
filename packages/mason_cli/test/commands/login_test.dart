import 'package:mason/mason.dart';
import 'package:mason_auth/mason_auth.dart';
import 'package:mason_cli/src/commands/commands.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

class MockMasonAuth extends Mock implements MasonAuth {}

class MockUser extends Mock implements User {}

void main() {
  group('LoginCommand', () {
    late Logger logger;
    late MasonAuth masonAuth;
    late LoginCommand loginCommand;

    setUp(() {
      logger = MockLogger();
      masonAuth = MockMasonAuth();
      loginCommand = LoginCommand(logger: logger, masonAuth: masonAuth);

      when(() => logger.progress(any())).thenReturn(([String? _]) {});
    });

    test('can be instantiated without any parameters', () {
      expect(() => LoginCommand(), returnsNormally);
    });

    test('exits with code 0 when already logged in', () async {
      const email = 'test@email.com';
      final user = MockUser();

      when(() => user.email).thenReturn(email);
      when(() => masonAuth.currentUser).thenReturn(user);

      final result = await loginCommand.run();
      expect(result, equals(ExitCode.success.code));

      verify(
        () => logger.info('You are already logged in as <${user.email}>'),
      ).called(1);
      verify(
        () => logger.info("Run 'mason logout' to log out and try again."),
      ).called(1);
    });

    test('exits with code 70 when MasonAuthLoginFailure occurs', () async {
      const email = 'test@email.com';
      const password = 'T0pS3cret!';
      const message = 'oops something went wrong!';
      when(
        () => logger.prompt('email:', defaultValue: any(named: 'defaultValue')),
      ).thenReturn(email);
      when(
        () => logger.prompt(
          'password:',
          defaultValue: any(named: 'defaultValue'),
          hidden: true,
        ),
      ).thenReturn(password);
      when(() => masonAuth.currentUser).thenReturn(null);
      when(
        () => masonAuth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(const MasonAuthLoginFailure(message: message));

      final result = await loginCommand.run();
      expect(result, equals(ExitCode.software.code));

      verify(() => logger.progress('Logging into brickhub.dev')).called(1);
      verify(
        () => masonAuth.login(email: email, password: password),
      ).called(1);
      verify(() => logger.err(message)).called(1);
    });

    test('exits with code 0 when logged in successfully', () async {
      const email = 'test@email.com';
      const password = 'T0pS3cret!';
      final user = MockUser();
      when(() => user.email).thenReturn(email);
      when(
        () => logger.prompt('email:', defaultValue: any(named: 'defaultValue')),
      ).thenReturn(email);
      when(
        () => logger.prompt(
          'password:',
          defaultValue: any(named: 'defaultValue'),
          hidden: true,
        ),
      ).thenReturn(password);
      when(() => masonAuth.currentUser).thenReturn(null);
      when(
        () => masonAuth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => user);

      final result = await loginCommand.run();
      expect(result, equals(ExitCode.success.code));

      verify(() => logger.progress('Logging into brickhub.dev')).called(1);
      verify(
        () => masonAuth.login(email: email, password: password),
      ).called(1);
      verify(
        () => logger.success('You are now logged in as <${user.email}>'),
      ).called(1);
    });
  });
}