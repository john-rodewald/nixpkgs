{
  lib,
  buildPythonPackage,
  fetchPypi,

  # build-system
  setuptools,
  setuptools-scm,

  # dependencies
  django,
}:

buildPythonPackage rec {
  pname = "django-notifications-community";
  version = "1.12.2";
  pyproject = true;

  src = fetchPypi {
    pname = "django_notifications_community";
    inherit version;
    hash = "sha256-C3FJGPpKcdva7bSacFCGwkU6XBEJpb23Uyrl13tkN1k=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [ django ];

  # Tests require a Django project setup
  doCheck = false;

  pythonImportsCheck = [ "notifications" ];

  meta = {
    description = "GitHub notifications alike app for Django";
    homepage = "https://github.com/django-notifications-community/django-notifications-community";
    changelog = "https://github.com/django-notifications-community/django-notifications-community/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.bsd3;
    maintainers = [ ];
  };
}
