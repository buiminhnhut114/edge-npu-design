/**
 * EdgeNPU Linux Driver
 * Kernel module for EdgeNPU device
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_device.h>
#include <linux/io.h>
#include <linux/interrupt.h>
#include <linux/dma-mapping.h>
#include <linux/fs.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>

#define DRIVER_NAME     "edge_npu"
#define DRIVER_VERSION  "1.0.0"

/* Register offsets */
#define REG_CTRL        0x000
#define REG_STATUS      0x004
#define REG_IRQ_EN      0x008
#define REG_IRQ_STATUS  0x00C
#define REG_VERSION     0x010
#define REG_CONFIG      0x014
#define REG_PERF_CNT    0x020
#define REG_DMA_CTRL    0x100
#define REG_DMA_STATUS  0x104
#define REG_DMA_SRC     0x108
#define REG_DMA_DST     0x10C
#define REG_DMA_LEN     0x110

/* Control register bits */
#define CTRL_ENABLE     BIT(0)
#define CTRL_START      BIT(1)
#define CTRL_RESET      BIT(2)

/* Status register bits */
#define STATUS_BUSY     BIT(0)
#define STATUS_DONE     BIT(1)
#define STATUS_ERROR    BIT(2)

/* Device structure */
struct edge_npu_dev {
    struct device *dev;
    void __iomem *regs;
    int irq;
    struct cdev cdev;
    dev_t devno;
    struct class *class;
    
    /* DMA */
    dma_addr_t weight_dma;
    void *weight_buf;
    size_t weight_size;
    
    dma_addr_t act_dma;
    void *act_buf;
    size_t act_size;
    
    /* Sync */
    struct completion done;
    spinlock_t lock;
};

/* IOCTLs */
#define NPU_IOC_MAGIC   'N'
#define NPU_IOC_START   _IO(NPU_IOC_MAGIC, 0)
#define NPU_IOC_WAIT    _IO(NPU_IOC_MAGIC, 1)
#define NPU_IOC_STATUS  _IOR(NPU_IOC_MAGIC, 2, uint32_t)
#define NPU_IOC_VERSION _IOR(NPU_IOC_MAGIC, 3, uint32_t)

/* Register access */
static inline u32 npu_read(struct edge_npu_dev *npu, u32 offset)
{
    return readl(npu->regs + offset);
}

static inline void npu_write(struct edge_npu_dev *npu, u32 offset, u32 value)
{
    writel(value, npu->regs + offset);
}

/* Interrupt handler */
static irqreturn_t edge_npu_irq(int irq, void *dev_id)
{
    struct edge_npu_dev *npu = dev_id;
    u32 status;
    
    status = npu_read(npu, REG_IRQ_STATUS);
    
    if (status & STATUS_DONE) {
        /* Clear interrupt */
        npu_write(npu, REG_IRQ_STATUS, status);
        complete(&npu->done);
        return IRQ_HANDLED;
    }
    
    return IRQ_NONE;
}

/* File operations */
static int edge_npu_open(struct inode *inode, struct file *file)
{
    struct edge_npu_dev *npu = container_of(inode->i_cdev, 
                                            struct edge_npu_dev, cdev);
    file->private_data = npu;
    return 0;
}

static int edge_npu_release(struct inode *inode, struct file *file)
{
    return 0;
}

static long edge_npu_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    struct edge_npu_dev *npu = file->private_data;
    u32 val;
    
    switch (cmd) {
    case NPU_IOC_START:
        npu_write(npu, REG_CTRL, CTRL_ENABLE | CTRL_START);
        break;
        
    case NPU_IOC_WAIT:
        wait_for_completion(&npu->done);
        reinit_completion(&npu->done);
        break;
        
    case NPU_IOC_STATUS:
        val = npu_read(npu, REG_STATUS);
        if (copy_to_user((void __user *)arg, &val, sizeof(val)))
            return -EFAULT;
        break;
        
    case NPU_IOC_VERSION:
        val = npu_read(npu, REG_VERSION);
        if (copy_to_user((void __user *)arg, &val, sizeof(val)))
            return -EFAULT;
        break;
        
    default:
        return -EINVAL;
    }
    
    return 0;
}

static const struct file_operations edge_npu_fops = {
    .owner          = THIS_MODULE,
    .open           = edge_npu_open,
    .release        = edge_npu_release,
    .unlocked_ioctl = edge_npu_ioctl,
};

/* Probe */
static int edge_npu_probe(struct platform_device *pdev)
{
    struct edge_npu_dev *npu;
    struct resource *res;
    int ret;
    
    dev_info(&pdev->dev, "EdgeNPU driver probe\n");
    
    npu = devm_kzalloc(&pdev->dev, sizeof(*npu), GFP_KERNEL);
    if (!npu)
        return -ENOMEM;
    
    npu->dev = &pdev->dev;
    platform_set_drvdata(pdev, npu);
    
    /* Map registers */
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    npu->regs = devm_ioremap_resource(&pdev->dev, res);
    if (IS_ERR(npu->regs))
        return PTR_ERR(npu->regs);
    
    /* Get IRQ */
    npu->irq = platform_get_irq(pdev, 0);
    if (npu->irq < 0)
        return npu->irq;
    
    ret = devm_request_irq(&pdev->dev, npu->irq, edge_npu_irq,
                           0, DRIVER_NAME, npu);
    if (ret)
        return ret;
    
    /* Initialize */
    spin_lock_init(&npu->lock);
    init_completion(&npu->done);
    
    /* Create char device */
    ret = alloc_chrdev_region(&npu->devno, 0, 1, DRIVER_NAME);
    if (ret)
        return ret;
    
    cdev_init(&npu->cdev, &edge_npu_fops);
    ret = cdev_add(&npu->cdev, npu->devno, 1);
    if (ret)
        goto err_cdev;
    
    npu->class = class_create(THIS_MODULE, DRIVER_NAME);
    if (IS_ERR(npu->class)) {
        ret = PTR_ERR(npu->class);
        goto err_class;
    }
    
    device_create(npu->class, NULL, npu->devno, NULL, DRIVER_NAME);
    
    dev_info(&pdev->dev, "EdgeNPU v%08x initialized\n", 
             npu_read(npu, REG_VERSION));
    
    return 0;

err_class:
    cdev_del(&npu->cdev);
err_cdev:
    unregister_chrdev_region(npu->devno, 1);
    return ret;
}

/* Remove */
static int edge_npu_remove(struct platform_device *pdev)
{
    struct edge_npu_dev *npu = platform_get_drvdata(pdev);
    
    device_destroy(npu->class, npu->devno);
    class_destroy(npu->class);
    cdev_del(&npu->cdev);
    unregister_chrdev_region(npu->devno, 1);
    
    dev_info(&pdev->dev, "EdgeNPU driver removed\n");
    return 0;
}

/* Device tree match */
static const struct of_device_id edge_npu_of_match[] = {
    { .compatible = "edge,npu-1.0" },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, edge_npu_of_match);

/* Platform driver */
static struct platform_driver edge_npu_driver = {
    .probe  = edge_npu_probe,
    .remove = edge_npu_remove,
    .driver = {
        .name = DRIVER_NAME,
        .of_match_table = edge_npu_of_match,
    },
};

module_platform_driver(edge_npu_driver);

MODULE_LICENSE("GPL v2");
MODULE_AUTHOR("EdgeNPU Team");
MODULE_DESCRIPTION("EdgeNPU Linux Driver");
MODULE_VERSION(DRIVER_VERSION);
