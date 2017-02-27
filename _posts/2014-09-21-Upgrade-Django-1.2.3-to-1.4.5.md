---
layout: post
title:  "Quick guide to upgrade Django from 1.2.3 to 1.4.5"
date:   2014-09-21 17:33:00
categories: development
tags: [python, django]
---

* TOC
{:toc}

As a Django/Python developer or maintainer, you may need at some point to upgrade one of your legacy applications or tools to a more recent or complete version of the framework. This was our case, as one of our stacks was written in Python2.6 and leveraged on Django 1.2.3. We required (1) a smooth migration and (2) provide backwards compatibility with 1.2. <!--more-->While the ideal scenario at this point in time was to directly upgrading to Django 1.6, migration was too cumbersome: e.g., it is mandatory to change paths for [many generic views](https://docs.djangoproject.com/en/1.4/topics/generic-views-migration/) and not every functionality seems to be there (e.g. the `get_model_and_form_class` method from the `create_update` view).
As a Django/Python developer or maintainer, you may need at some point to upgrade one of your legacy applications or tools to a more recent or complete version of the framework. This was our case, as one of our stacks was written in Python2.6 and leveraged on Django 1.2.3. We required (1) a smooth migration and (2) provide backwards compatibility with 1.2. While the ideal scenario at this point in time was to directly upgrading to Django 1.6, migration was too cumbersome: e.g., it is mandatory to change paths for [many generic views](https://docs.djangoproject.com/en/1.4/topics/generic-views-migration/) and not every functionality seems to be there (e.g. the `get_model_and_form_class` method from the `create_update` view).

Note that these generic views are already introduce in 1.4, but its use is not enforced. Similarly, there are many other modifications (see [Django 1.4 release notes](https://docs.djangoproject.com/en/1.5/releases/1.4/)) that are introduced in this version but its use is <stress>not enforced</stress>.

Below you will find a short guide in order perform a quick migration. Note that this is limited to a specific scope, and may be just <stress>a subset of required modifications</stress> needed for your app to work. If you have enough time to experiment, my advice is that you investigate the differences across versions and attempt to migrate to the latest stable versions. This way you'll pave the road for further upgrades.

### New settings

#### DATABASES structure

In our case, we provide settings files to be modified by the user. The `DATABASES` structure should be added into your app's static settings, far away from any potential modification from the user's side. In any case, the user is not interested in this structure, right?

```python
DATABASES = {
    'default': {
        'ENGINE': "django.db.backends.%s" % DATABASE_ENGINE,
        'NAME': DATABASE_NAME,
        'USER': DATABASE_USER,
        'PASSWORD': DATABASE_PASSWORD,
        'HOST': DATABASE_HOST,
    }
}
```

### Updated settings

#### TEMPLATE_LOADERS

Both the package and module name for the template loaders is changed in Django 1.4.5.

```python
TEMPLATE_LOADERS = (
    'django.template.loaders.filesystem.load_template_source',
    'django.template.loaders.app_directories.load_template_source',
)
```
```python
TEMPLATE_LOADERS = [
        ('django.template.loaders.cached.Loader',(
            'django.template.loaders.filesystem.Loader',
            'django.template.loaders.app_directories.Loader',
            )),
]
```

### Updated fields

#### XMLField

This field, once present in Django 1.2.3, is no longer supported. It must be changed to a `TextField` to work under Django 1.4.5. This field already existed under Django, therefore this change shall not affect your app, whether it runs under 1.2.3 or 1.4.5.

```python
from django.db import models
rspec = models.XMLField("DataModel", editable=False,)
```

```python
from django.db import models
rspec = models.TextField("DataModel", editable=False,)
```
