package anaml

import (
	"strconv"

	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/schema"
	"github.com/hashicorp/terraform-plugin-sdk/v2/helper/validation"
)

func ResourceFeatureStore() *schema.Resource {
	return &schema.Resource{
		Create: resourceFeatureStoreCreate,
		Read:   resourceFeatureStoreRead,
		Update: resourceFeatureStoreUpdate,
		Delete: resourceFeatureStoreDelete,
		Importer: &schema.ResourceImporter{
			State: schema.ImportStatePassthrough,
		},

		Schema: map[string]*schema.Schema{
			"name": {
				Type:     schema.TypeString,
				Required: true,
			},
			"description": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"start_date": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"end_date": {
				Type:     schema.TypeString,
				Optional: true,
			},
			"feature_set": {
				Type:         schema.TypeString,
				Required:     true,
				ValidateFunc: validateAnamlIdentifier(),
			},
			"enabled": {
				Type:     schema.TypeBool,
				Required: true,
			},
			"daily_schedule": {
				Type:          schema.TypeList,
				Optional:      true,
				MaxItems:      1,
				Elem:          dailyScheduleSchema(),
				ConflictsWith: []string{"cron_schedule"},
			},
			"cron_schedule": {
				Type:          schema.TypeList,
				Optional:      true,
				MaxItems:      1,
				Elem:          cronScheduleSchema(),
				ConflictsWith: []string{"daily_schedule"},
			},
			"destination": {
				Type:     schema.TypeList,
				Optional: true,
				Elem:     destinationSchema(),
			},
			"cluster": {
				Type:         schema.TypeString,
				Required:     true,
				ValidateFunc: validateAnamlIdentifier(),
			},
		},
	}
}

func destinationSchema() *schema.Resource {
	return &schema.Resource{
		Schema: map[string]*schema.Schema{
			"destination": {
				Type:         schema.TypeString,
				Required:     true,
				ValidateFunc: validateAnamlIdentifier(),
			},
			"folder": {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
			"table_name": {
				Type:         schema.TypeString,
				Optional:     true,
				ValidateFunc: validation.StringIsNotWhiteSpace,
			},
		},
	}
}

func resourceFeatureStoreRead(d *schema.ResourceData, m interface{}) error {
	c := m.(*Client)
	FeatureStoreID := d.Id()

	FeatureStore, err := c.GetFeatureStore(FeatureStoreID)
	if err != nil {
		return err
	}
	if FeatureStore == nil {
		d.SetId("")
		return nil
	}

	if err := d.Set("name", FeatureStore.Name); err != nil {
		return err
	}
	if err := d.Set("description", FeatureStore.Description); err != nil {
		return err
	}
	if FeatureStore.StartDate != nil {
		if err := d.Set("start_date", *FeatureStore.StartDate); err != nil {
			return err
		}
	}
	if FeatureStore.EndDate != nil {
		if err := d.Set("end_date", *FeatureStore.EndDate); err != nil {
			return err
		}
	}
	if err := d.Set("feature_set", strconv.Itoa(FeatureStore.FeatureSet)); err != nil {
		return err
	}
	if err := d.Set("enabled", FeatureStore.Enabled); err != nil {
		return err
	}
	if err := d.Set("destination", flattenDestinationReferences(FeatureStore.Destinations)); err != nil {
		return err
	}
	if err := d.Set("cluster", strconv.Itoa(FeatureStore.Cluster)); err != nil {
		return err
	}

	if FeatureStore.Schedule.Type == "daily" {
		dailySchedules, err := parseDailySchedule(FeatureStore.Schedule)
		if err != nil {
			return err
		}
		if err := d.Set("daily_schedule", dailySchedules); err != nil {
			return err
		}
	}

	if FeatureStore.Schedule.Type == "cron" {
		cronSchedules, err := parseCronSchedule(FeatureStore.Schedule)
		if err != nil {
			return err
		}
		if err := d.Set("cron_schedule", cronSchedules); err != nil {
			return err
		}
	}

	return err
}

func resourceFeatureStoreCreate(d *schema.ResourceData, m interface{}) error {
	c := m.(*Client)
	FeatureStore, err := composeFeatureStore(d)
	if err != nil {
		return err
	}

	e, err := c.CreateFeatureStore(*FeatureStore)
	if err != nil {
		return err
	}

	d.SetId(strconv.Itoa(e.ID))
	return err
}

func resourceFeatureStoreUpdate(d *schema.ResourceData, m interface{}) error {
	c := m.(*Client)
	FeatureStoreID := d.Id()
	FeatureStore, err := composeFeatureStore(d)
	if err != nil {
		return err
	}

	err = c.UpdateFeatureStore(FeatureStoreID, *FeatureStore)
	if err != nil {
		return err
	}

	return nil
}

func composeFeatureStore(d *schema.ResourceData) (*FeatureStore, error) {
	featureSet, err := strconv.Atoi(d.Get("feature_set").(string))
	if err != nil {
		return nil, err
	}

	cluster, err := strconv.Atoi(d.Get("cluster").(string))
	if err != nil {
		return nil, err
	}

	if dailySchedule, _ := expandSingleMap(d.Get("daily_schedule")); dailySchedule != nil {
		schedule, err := composeDailySchedule(dailySchedule)
		if err != nil {
			return nil, err
		}
		return &FeatureStore{
			Name:         d.Get("name").(string),
			Description:  d.Get("description").(string),
			StartDate:    getNullableString(d, "start_date"),
			EndDate:      getNullableString(d, "end_date"),
			FeatureSet:   featureSet,
			Enabled:      d.Get("enabled").(bool),
			Destinations: expandDestinationReferences(d),
			Cluster:      cluster,
			Schedule:     schedule,
		}, nil
	}

	if cronSchedule, _ := expandSingleMap(d.Get("cron_schedule")); cronSchedule != nil {
		schedule, err := composeCronSchedule(cronSchedule)
		if err != nil {
			return nil, err
		}
		return &FeatureStore{
			Name:         d.Get("name").(string),
			Description:  d.Get("description").(string),
			StartDate:    getNullableString(d, "start_date"),
			EndDate:      getNullableString(d, "end_date"),
			FeatureSet:   featureSet,
			Enabled:      d.Get("enabled").(bool),
			Destinations: expandDestinationReferences(d),
			Cluster:      cluster,
			Schedule:     schedule,
		}, nil
	}

	schedule := composeNeverSchedule()

	return &FeatureStore{
		Name:         d.Get("name").(string),
		Description:  d.Get("description").(string),
		StartDate:    getNullableString(d, "start_date"),
		EndDate:      getNullableString(d, "end_date"),
		FeatureSet:   featureSet,
		Enabled:      d.Get("enabled").(bool),
		Destinations: expandDestinationReferences(d),
		Cluster:      cluster,
		Schedule:     schedule,
	}, nil
}

func resourceFeatureStoreDelete(d *schema.ResourceData, m interface{}) error {
	c := m.(*Client)
	FeatureStoreID := d.Id()

	err := c.DeleteFeatureStore(FeatureStoreID)
	if err != nil {
		return err
	}

	return nil
}

func expandDestinationReferences(d *schema.ResourceData) []DestinationReference {
	drs := d.Get("destination").([]interface{})
	res := make([]DestinationReference, 0, len(drs))

	for _, dr := range drs {
		val, _ := dr.(map[string]interface{})
		destId, _ := strconv.Atoi(val["destination"].(string))

		parsed := DestinationReference{
			DestinationID: destId,
			Folder:        val["folder"].(string),
			TableName:     val["table_name"].(string),
		}
		res = append(res, parsed)
	}

	return res
}

func flattenDestinationReferences(destinations []DestinationReference) []map[string]interface{} {
	res := make([]map[string]interface{}, 0, len(destinations))

	for _, destination := range destinations {
		single := make(map[string]interface{})
		single["destination"] = strconv.Itoa(destination.DestinationID)
		single["folder"] = destination.Folder
		single["table_name"] = destination.TableName
		res = append(res, single)
	}

	return res
}
